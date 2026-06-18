#!/usr/bin/env bash
set -euo pipefail

# One-time setup: RKE2 (single node) + NVIDIA GPU Operator on SLES 16
# Prerequisites: NVIDIA drivers installed and working, Docker able to run nvidia-smi

KUBECONFIG=/etc/rancher/rke2/rke2.yaml
KUBECTL=/var/lib/rancher/rke2/bin/kubectl
GPU_OPERATOR_NS=gpu-operator
GPU_OPERATOR_CHART=nvidia/gpu-operator
LOCAL_PATH_MANIFEST="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"

# ── helpers ──────────────────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
die()   { echo "[ERROR] $*" >&2; exit 1; }

require_root() {
  [[ $EUID -eq 0 ]] || die "This script must be run as root."
}

# ── Firewall ─────────────────────────────────────────────────────────────────

configure_firewall() {
  if ! command -v firewall-cmd &>/dev/null; then
    info "firewalld not found — skipping firewall configuration."
    return
  fi

  if ! systemctl is-active --quiet firewalld; then
    info "firewalld is not running — skipping firewall configuration."
    return
  fi

  info "Configuring firewall rules for RKE2..."

  local ports=(
    "80/tcp"    # HTTP ingress
    "443/tcp"   # HTTPS ingress
    "6443/tcp"  # Kubernetes API server
    "10250/tcp" # Kubelet API (required by metrics-server)
  )

  for port in "${ports[@]}"; do
    if firewall-cmd --query-port="${port}" --permanent &>/dev/null; then
      info "  ${port} already open — skipping."
    else
      firewall-cmd --add-port="${port}" --permanent
      info "  Opened ${port}."
    fi
  done

  firewall-cmd --reload
  info "Firewall rules applied."
}

# ── RKE2 ─────────────────────────────────────────────────────────────────────

install_rke2() {
  if systemctl is-active --quiet rke2-server 2>/dev/null; then
    info "RKE2 is already running — skipping install."
    return
  fi

  info "Installing RKE2 (latest stable)..."
  curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=stable sh -

  info "Enabling rke2-server..."
  systemctl enable rke2-server

  info "Starting rke2-server..."
  systemctl start rke2-server

  info "Waiting for node to become Ready..."
  local timeout=180 elapsed=0
  until KUBECONFIG=${KUBECONFIG} ${KUBECTL} get node --no-headers 2>/dev/null \
      | awk '{print $2}' | grep -q "^Ready$"; do
    if (( elapsed >= timeout )); then
      die "Node did not become Ready within ${timeout}s."
    fi
    sleep 5
    (( elapsed += 5 ))
  done
  info "Node is Ready."
}

configure_kubeconfig() {
  local user_home
  user_home=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
  local dest="${user_home}/.kube/config"

  info "Writing kubeconfig to ${dest}..."
  install -d -m 0700 "${user_home}/.kube"
  install -m 0600 "${KUBECONFIG}" "${dest}"
  info "Set KUBECONFIG=${dest} or add to your shell profile."
}

# ── Helm ─────────────────────────────────────────────────────────────────────

install_helm() {
  if command -v helm &>/dev/null; then
    info "Helm already installed: $(helm version --short)"
    return
  fi

  info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

# ── NVIDIA GPU Operator ───────────────────────────────────────────────────────

install_gpu_operator() {
  export KUBECONFIG=${KUBECONFIG}

  if helm list -n ${GPU_OPERATOR_NS} 2>/dev/null | grep -q gpu-operator; then
    info "GPU Operator already installed — skipping."
    return
  fi

  info "Adding NVIDIA Helm repo..."
  helm repo add nvidia https://helm.ngc.nvidia.com/nvidia || true
  helm repo update

  info "Installing GPU Operator (driver.enabled=false — using pre-installed drivers)..."
  ${KUBECTL} create namespace ${GPU_OPERATOR_NS} --dry-run=client -o yaml \
    | ${KUBECTL} apply -f -

  helm install gpu-operator ${GPU_OPERATOR_CHART} \
    --namespace ${GPU_OPERATOR_NS} \
    --set driver.enabled=false \
    --wait --timeout=10m

  info "GPU Operator installed."
}

verify_gpu_operator() {
  export KUBECONFIG=${KUBECONFIG}
  info "Verifying GPU Operator pods..."
  ${KUBECTL} get pods -n ${GPU_OPERATOR_NS}
}

# ── Local Path Provisioner ────────────────────────────────────────────────────

install_local_path_provisioner() {
  export KUBECONFIG=${KUBECONFIG}

  if ${KUBECTL} get storageclass local-path &>/dev/null; then
    info "local-path StorageClass already exists — skipping."
    return
  fi

  info "Installing local-path-provisioner..."
  ${KUBECTL} apply -f "${LOCAL_PATH_MANIFEST}"

  info "Setting local-path as the default StorageClass..."
  ${KUBECTL} patch storageclass local-path \
    -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

  info "local-path-provisioner installed. Backing dir: /opt/local-path-provisioner"
}

# ── main ─────────────────────────────────────────────────────────────────────

require_root
configure_firewall
install_rke2
configure_kubeconfig
install_helm
install_gpu_operator
verify_gpu_operator
install_local_path_provisioner

info ""
info "Install complete."
info "  kubectl: ${KUBECTL}"
info "  kubeconfig: ${KUBECONFIG}"
info "  GPU Operator namespace: ${GPU_OPERATOR_NS}"
info "  StorageClass: local-path (default, backing dir: /opt/local-path-provisioner)"
