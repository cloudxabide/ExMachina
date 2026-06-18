# Jarvis Overview

Jarvis (`10.10.12.250`) is the homelab's medium-GPU inference and MLOps node.

## Hardware

| Item | Detail |
|------|--------|
| Host | Asus i9 workstation |
| GPU | NVIDIA RTX 4060 Ti — 16GB VRAM |
| RAM | ~128GB DDR5 |
| Storage | 1.8TB NVMe (nvme0n1p4: 836GB free on `/`) |
| OS | SLES 16 |
| SSH | `ssh -i ~/.ssh/id_ecdsa-kubernerdes jradtke@10.10.12.250` |

---

## Kubernetes: Single-Node RKE2

Jarvis runs a single-node RKE2 cluster registered with Rancher Manager.

```bash
export KUBECONFIG=~/.kube/jarvis.kubeconfig   # from your local Mac
# or on the node:
sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl ...
```

### Cluster Components

| Component | Namespace | Notes |
|-----------|-----------|-------|
| RKE2 | — | v1.35.5+rke2r2, control-plane + etcd on same node |
| GPU Operator | `gpu-operator` | NVIDIA drivers pre-installed; `driver.enabled=false` |
| metrics-server | `kube-system` | Fixed: firewall port 10250 opened |
| local-path-provisioner | `local-path-storage` | Default StorageClass; backing dir `/opt/local-path-provisioner` |

**Firewall ports open:** 80/tcp, 443/tcp, 6443/tcp (K8s API), 10250/tcp (kubelet — required by metrics-server)

### Management Script

`bin/jarvisctl` — run as root on the node:

```bash
jarvisctl start      # start rke2-server, wait for Ready
jarvisctl stop       # stop rke2-server
jarvisctl status     # show node + GPU Operator pod state
jarvisctl test       # run nvidia-smi in a K8s pod (GPU smoke test)
jarvisctl update     # pull latest RKE2 stable
jarvisctl self-update
```

---

## Inference: vLLM + NemoTron

### Recommended Models for 16GB VRAM

| Short Name | HuggingFace ID | Quant | Est. VRAM | Notes |
|------------|---------------|-------|-----------|-------|
| `nemotron-elastic-12b` | `nvidia/Nemotron-Elastic-12B` | FP8 | ~12GB | **Primary — best fit** |
| `nemotron-nano-4b` | `nvidia/Nemotron-3-Nano-4B` | — | ~5GB | Fast / latency-sensitive |
| `llama-3.1-8b` | `meta-llama/Meta-Llama-3.1-8B-Instruct` | — | ~16GB | |
| `qwen2.5-14b-int4` | `Qwen/Qwen2.5-14B-Instruct-GPTQ-Int4` | GPTQ | ~8GB | |
| `deepseek-r1-7b` | `deepseek-ai/DeepSeek-R1-Distill-Qwen-7B` | — | ~14GB | |

All five models are in `bin/vllmctl` under the `medium` GPU profile and appear automatically when vllmctl detects a ≤20GB GPU.

### Option A — Docker (quick start)

```bash
export HF_TOKEN=<your-token>
vllmctl start        # interactive model picker → starts Docker container on port 8000
vllmctl proxy start  # optional: LiteLLM proxy on port 4000 for Claude Code / OpenCode
```

### Option B — Kubernetes Deployment

```bash
kubectl create secret generic hf-token --from-literal=HF_TOKEN=<your-token>
kubectl apply -f files/jarvis/vllm-nemotron-12b.yaml
# vLLM exposed at NodePort 30800 → http://10.10.12.250:30800
```

### NemoClaw

NemoClaw cannot run natively inside Kubernetes (OpenShell requires direct Docker daemon access; no K8s manifests exist from NVIDIA). The correct split for Jarvis:

- **vLLM** — runs inside K8s (Deployment + NodePort :30800)
- **NemoClaw** — runs on the host (Docker, outside K8s), configured with `http://localhost:30800` as inference endpoint

This mirrors the DGX Spark pattern. See `ARCHITECTURE.md` for the full decision record.

---

## MLOps Stack

Three-component pipeline for model visibility and automated benchmarking.

### Deploy Order

#### Phase 1 — Runtime Monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f files/jarvis/mlops/prometheus-values.yaml

kubectl apply -f files/jarvis/mlops/vllm-servicemonitor.yaml
kubectl apply -f files/jarvis/mlops/grafana-vllm-dashboard.yaml
```

**Grafana:** `http://10.10.12.250:30300` (admin / changeme)

Dashboard panels: TTFT p50/p95/p99, tokens/s, queue depth, KV cache %, GPU utilization, GPU power, GPU temperature.

#### Phase 2 — Model Registry + Experiment Tracking

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install mlflow bitnami/mlflow \
  -n mlflow --create-namespace \
  -f files/jarvis/mlops/mlflow-values.yaml
```

**MLflow:** `http://10.10.12.250:30500`

Experiment: `jarvis-inference-models` — each run records model ID, quantization, vLLM flags, and benchmark scores.

#### Phase 3 — Test Suite

```bash
kubectl apply -f files/jarvis/mlops/eval-results-pvc.yaml
kubectl apply -f files/jarvis/mlops/eval-config.yaml
kubectl apply -f files/jarvis/mlops/eval-cronjob.yaml
```

Runs nightly at **03:00**. Benchmarks: MMLU, ARC-Easy, GSM8K — via LM-Eval Harness against the live vLLM endpoint. Results logged to MLflow automatically.

Manual trigger:
```bash
kubectl create job --from=cronjob/eval-nemotron-12b manual-$(date +%s) -n vllm
```

### MLOps Resource Footprint

| Component | RAM | Storage (PVC) |
|-----------|-----|--------------|
| Prometheus | ~1.5GB | 50Gi |
| Grafana | ~500MB | 10Gi |
| AlertManager | ~200MB | 5Gi |
| MLflow + PostgreSQL | ~1.5GB | 100Gi + 20Gi |
| eval-results PVC | — | 20Gi |
| **Total** | **~3.7GB** | **~205Gi** |

---

## Files Reference

```
files/jarvis/
  jarvis-install.sh               # One-time setup: RKE2 + GPU Operator + local-path
  local-path-storage.yaml         # local-path-provisioner manifest (air-gap copy)
  vllm-nemotron-12b.yaml          # K8s Deployment + Service + PVC for vLLM
  mlops/
    prometheus-values.yaml        # kube-prometheus-stack Helm values
    vllm-servicemonitor.yaml      # Prometheus scrape target for vLLM /metrics
    grafana-vllm-dashboard.yaml   # Grafana dashboard ConfigMap (auto-loaded)
    mlflow-values.yaml            # bitnami/mlflow Helm values
    eval-results-pvc.yaml         # 20Gi PVC for benchmark JSON output
    eval-config.yaml              # ConfigMap: tasks, MLflow URI, vLLM endpoint
    eval-cronjob.yaml             # Nightly LM-Eval Harness CronJob
```
