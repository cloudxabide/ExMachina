# DGX Spark Monitoring & Cost-Comparison Dashboard

**Status: deployed and verified, 2026-07-14.** This started as a runbook and is now a
record of what's actually running — spark-e's (`10.10.12.251`) vLLM throughput and GPU
metrics feed into the Grafana instance already running on the Harvester cluster, plus a
cost-comparison panel showing what the same workload would have cost on a hyperscaler or
hosted API, next to what it actually cost in electricity.

Live dashboards (Harvester Grafana, `cattle-monitoring-system` — see access instructions
in Verification below): **vLLM Metrics**, **Node Exporter Full**, **DGX Spark — Cost
Comparison**.

## Why Harvester's Grafana, not a new stack on the DGX

spark-e is dedicated inference compute — the north star in `CLAUDE.md` puts orchestration
and services on the Harvester cluster, not the GPU box. Standing up a second
Prometheus/Grafana pair directly on the DGX (the pattern shown in a walkthrough video we
looked at — [Ryan Susman's DGX Spark build](https://www.youtube.com/watch?v=MBNfnJstZ7w),
repo: [`darkmatter2222/GithubCopilotExit`](https://github.com/darkmatter2222/GithubCopilotExit))
works fine as a single-box demo, but it duplicates infrastructure you already run and
maintain. Harvester already has a full Prometheus Operator stack — we just need to point
it at spark-e as a remote scrape target.

**What's actually running on Harvester today** (confirmed directly against the cluster,
not assumed from docs):

| Component | Detail |
|---|---|
| Helm release | `rancher-monitoring` (Rancher's bundled `kube-prometheus-stack` fork) in `cattle-monitoring-system` |
| Prometheus | Operator-managed, svc `rancher-monitoring-prometheus:9090`; `serviceMonitorSelector` and `serviceMonitorNamespaceSelector` are both empty — **any `ServiceMonitor` in any namespace is picked up automatically**, no label required |
| Grafana | svc `rancher-monitoring-grafana:80` (ClusterIP only — no Ingress found, so access today is via `kubectl port-forward` or the Rancher UI's embedded monitoring proxy) |
| Dashboard auto-loading | A `grafana-sc-dashboard` sidecar watches `ConfigMap`s in the **`cattle-dashboards`** namespace labeled `grafana_dashboard: "1"` and hot-loads them — this is how `rancher-default-dashboards-*` and Harvester's own VM dashboards get in |
| Default Prometheus datasource | UID `prometheus`, name `Prometheus`, `isDefault: true` |

That last point matters: it's the same ConfigMap-sidecar pattern already documented in
`ARCHITECTURE.md` for Jarvis's MLOps stack (`grafana-vllm-dashboard.yaml`) — we're reusing
a pattern that already exists in this repo, just targeting the Harvester release instead
of Jarvis's.

## The plan

1. Expose metrics on spark-e (vLLM, host, GPU power).
2. Register spark-e as an external Prometheus scrape target (it's not a cluster member,
   so this needs a headless `Service` + `Endpoints`, not a normal pod selector).
3. Import two known-good community dashboards by ID (vLLM: `25263`, Node Exporter:
   `1860`) as sidecar-loaded ConfigMaps.
4. Build a small textfile exporter for the cost-comparison numbers, since neither vLLM
   nor Node Exporter has any concept of electricity price or cloud pricing.
5. Add a custom Stat-panel dashboard for the cost comparison itself.

---

## Step 1 — Expose metrics on spark-e

### vLLM

vLLM already exposes Prometheus-format metrics natively at `/metrics` on whatever port
it's serving on — no extra work needed here beyond confirming the port. spark-e runs
vLLM via `bin/vllmctl`, which defaults to `VLLM_PORT=8000` — that's the port used
throughout this doc (Ryan's systemd-based setup used `8006`, which is why it showed up
as an alternative during planning, but it doesn't apply here).

Confirmed live, serving `nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4`:

```bash
curl -s http://10.10.12.251:8000/metrics | head
```

(An earlier attempt to serve `nvidia/Qwen3.6-27B-NVFP4` on this same image failed during
weight loading — `RuntimeError: start (0) + length (17408) exceeds dimension size
(8704)` in vLLM's `qwen3_5.py` row-parallel weight loader. Likely a checkpoint/loader
version mismatch, since NVIDIA's README for that model recommends the
`vllm/vllm-openai:nightly` image rather than the pinned
`nvcr.io/nvidia/vllm:26.03.post1-py3`. Not a monitoring-stack issue — noted here in case
it recurs.)

### Host metrics — node_exporter

spark-e isn't a Kubernetes node, so it needs its own `node_exporter`, run directly on the
host (systemd is simplest, keeps it independent of whatever container runtime vLLM is
using):

```bash
# on spark-e — check github.com/prometheus/node_exporter/releases for the current
# version; 1.12.0 was latest as of this deployment
curl -fsSL https://github.com/prometheus/node_exporter/releases/download/v1.12.0/node_exporter-1.12.0.linux-arm64.tar.gz \
  -o /tmp/node_exporter.tar.gz
sudo tar -C /usr/local/bin --strip-components=1 -xzf /tmp/node_exporter.tar.gz \
  node_exporter-1.12.0.linux-arm64/node_exporter

sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chown "$(whoami)":"$(whoami)" /var/lib/node_exporter/textfile_collector

sudo tee /etc/systemd/system/node_exporter.service >/dev/null <<'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector \
  --web.listen-address=:9100
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
```

(GB10 is `aarch64` — grab the `linux-arm64` release, not `amd64`.)

### GPU power / utilization — no containerized DCGM on ARM64

Ryan's repo notes this explicitly and it's worth repeating: the standard `nvcr.io/nvidia/dcgm-exporter`
container image is AMD64-only, so it won't run on DGX Spark's ARM64 (Grace-Blackwell)
host. Rather than chase a native DCGM install, the simplest reliable path is a tiny
systemd timer that shells out to `nvidia-smi` (which does work fine — it's part of the
driver, not DCGM) and writes a Prometheus textfile that `node_exporter` picks up
automatically from the directory configured above.

**One thing confirmed only by actually running this on spark-e:** `nvidia-smi
--query-gpu=memory.used,memory.total` returns `[N/A]` here — DGX Spark's unified memory
architecture doesn't expose separate VRAM the way a discrete GPU does, since GPU and CPU
share the same memory pool. The script below drops the memory field and substitutes GPU
temperature instead; for actual memory pressure, use `node_exporter`'s normal host memory
metrics (`node_memory_*`), not a GPU-specific one.

```bash
# /usr/local/bin/gpu-textfile-exporter.sh
#!/usr/bin/env bash
set -euo pipefail
OUT=/var/lib/node_exporter/textfile_collector/gpu.prom
TMP="${OUT}.$$"

IFS=',' read -r power util temp <<< "$(nvidia-smi \
  --query-gpu=power.draw,utilization.gpu,temperature.gpu \
  --format=csv,noheader,nounits | tr -d ' ')"

cat > "$TMP" <<EOF
# HELP dgx_gpu_power_watts Instantaneous GPU power draw (nvidia-smi)
# TYPE dgx_gpu_power_watts gauge
dgx_gpu_power_watts ${power}
# HELP dgx_gpu_utilization_percent GPU utilization percent
# TYPE dgx_gpu_utilization_percent gauge
dgx_gpu_utilization_percent ${util}
# HELP dgx_gpu_temperature_celsius GPU temperature, Celsius
# TYPE dgx_gpu_temperature_celsius gauge
dgx_gpu_temperature_celsius ${temp}
EOF
mv "$TMP" "$OUT"
```

```bash
sudo chmod +x /usr/local/bin/gpu-textfile-exporter.sh

sudo tee /etc/systemd/system/gpu-textfile-exporter.timer >/dev/null <<'EOF'
[Unit]
Description=Run gpu-textfile-exporter every 10s

[Timer]
OnBootSec=10s
OnUnitActiveSec=10s

[Install]
WantedBy=timers.target
EOF

sudo tee /etc/systemd/system/gpu-textfile-exporter.service >/dev/null <<'EOF'
[Unit]
Description=GPU metrics -> node_exporter textfile

[Service]
Type=oneshot
User=jradtke
ExecStart=/usr/local/bin/gpu-textfile-exporter.sh
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now gpu-textfile-exporter.timer
```

`dgx_gpu_power_watts` from this script is what feeds the cost-comparison math in Step 4.

---

## Step 2 — Register spark-e as a Prometheus target

Because spark-e isn't a pod in the Harvester cluster, `ServiceMonitor`'s normal pod-label
selection doesn't apply. The standard Prometheus Operator pattern for an off-cluster
target is a `Service` with no selector, paired with a manually-defined `Endpoints` object
pointing at the real IP.

**Use `v1 Endpoints`, not `EndpointSlice`, despite the deprecation warning.** The first
attempt here used `discovery.k8s.io/v1 EndpointSlice` to avoid the "v1 Endpoints is
deprecated in v1.33+" warning kubectl prints on this cluster (RKE2 v1.34.3) — that
silently broke discovery. Inspecting the generated scrape config in
`secret/prometheus-rancher-monitoring-prometheus` showed this Prometheus Operator version
generates `kubernetes_sd_configs: - role: endpoints` for ServiceMonitors, which only
discovers targets from `Endpoints` objects, not `EndpointSlice`. The deprecation warning
is real but harmless here — the API is still fully functional in 1.34, and it's what this
stack's service discovery actually reads:

```yaml
# files/harvester/monitoring/spark-e-external-target.yaml
apiVersion: v1
kind: Service
metadata:
  name: spark-e-external
  namespace: cattle-monitoring-system
  labels:
    app: spark-e-external
spec:
  ports:
    - name: vllm
      port: 8000
      targetPort: 8000
    - name: node-exporter
      port: 9100
      targetPort: 9100
---
apiVersion: v1
kind: Endpoints
metadata:
  name: spark-e-external
  namespace: cattle-monitoring-system
subsets:
  - addresses:
      - ip: 10.10.12.251
    ports:
      - name: vllm
        port: 8000
      - name: node-exporter
        port: 9100
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: spark-e-external
  namespace: cattle-monitoring-system
spec:
  selector:
    matchLabels:
      app: spark-e-external
  endpoints:
    - port: vllm
      path: /metrics
      interval: 15s
    - port: node-exporter
      path: /metrics
      interval: 15s
```

Adjust the `vllm` port to match whatever's actually running (see Step 1). Applied via:

```bash
export KUBECONFIG=~/.kube/community-harvester.kubeconfig
kubectl apply -f files/harvester/monitoring/spark-e-external-target.yaml
```

Since `serviceMonitorSelector: {}` on the Harvester Prometheus CR, no extra labeling or
release-name matching is needed — this got picked up automatically. Confirmed both
sub-targets `up` with no scrape errors:

```bash
kubectl port-forward -n cattle-monitoring-system svc/rancher-monitoring-prometheus 9090:9090
curl -s 'http://localhost:9090/api/v1/targets' | python3 -c \
  "import sys,json; d=json.load(sys.stdin); [print(t['scrapePool'], t['health']) for t in d['data']['activeTargets'] if 'spark-e' in t['scrapePool']]"
# serviceMonitor/cattle-monitoring-system/spark-e-external/0  up   (vllm:8000/metrics)
# serviceMonitor/cattle-monitoring-system/spark-e-external/1  up   (node-exporter:9100/metrics)
```

---

## Step 3 — Import the reference dashboards

Both dashboards Ryan used are stock community dashboards, importable by ID — no need to
hand-roll panel JSON for throughput/latency/KV-cache:

- **25263** — vLLM metrics
- **1860** — Node Exporter Full

Since Grafana here is provisioned via the ConfigMap sidecar (not manual UI import), pull
each dashboard's JSON from the Grafana.com API and wrap it in a labeled ConfigMap in the
`cattle-dashboards` namespace:

```bash
mkdir -p /tmp/dgx-dashboards
for id_name in "25263:vllm" "1860:node-exporter-full"; do
  id="${id_name%%:*}"; name="${id_name##*:}"
  curl -s "https://grafana.com/api/dashboards/${id}/revisions/latest/download" \
    -o "/tmp/dgx-dashboards/${name}-dashboard.json"
done
```

**Gotcha #1 — datasource template variable:** `vllm-dashboard.json` templates its
datasource as `${DS_PROMETHEUS}` (confirmed by inspecting `__inputs` / panel
`datasource.uid` in the downloaded JSON). When provisioned via ConfigMap (rather than the
UI's "import" flow, which prompts you to map it), that template variable doesn't
resolve. Patch it to the real datasource UID (`prometheus`, confirmed as this cluster's
default) before creating the ConfigMap:

```bash
python3 -c "
import json
path = '/tmp/dgx-dashboards/vllm-dashboard.json'
raw = open(path).read().replace('\${DS_PROMETHEUS}', 'prometheus')
d = json.loads(raw)
d.pop('__inputs', None)
d.pop('id', None)
json.dump(d, open(path, 'w'), indent=2)
"
```

(Node Exporter Full has no explicit per-panel datasource, so it falls through to the
default datasource with no patching needed.)

**Gotcha #2 — `kubectl apply` on a large ConfigMap:** `node-exporter-full-dashboard.json`
is ~470KB. `kubectl apply` stores the full payload a second time in the
`kubectl.kubernetes.io/last-applied-configuration` annotation, which blows past the
262144-byte annotation size limit. Use `kubectl create` (no last-applied annotation)
instead, and label separately rather than trying to inject the label into a
`--dry-run=client` YAML with a YAML library (not guaranteed to be installed):

```bash
export KUBECONFIG=~/.kube/community-harvester.kubeconfig
for name in vllm node-exporter-full; do
  kubectl create configmap "${name}-grafana-dashboard" \
    --from-file="${name}-dashboard.json=/tmp/dgx-dashboards/${name}-dashboard.json" \
    -n cattle-dashboards
  kubectl label configmap "${name}-grafana-dashboard" -n cattle-dashboards grafana_dashboard=1
done
```

Confirmed both loaded by tailing the sidecar's logs and checking Grafana's search API:

```bash
kubectl logs -n cattle-monitoring-system deploy/rancher-monitoring-grafana \
  -c grafana-sc-dashboard --tail=20 | grep -i "Writing /tmp/dashboards"
# {"msg": "Writing /tmp/dashboards/vllm-dashboard.json (ascii)"}
# {"msg": "Writing /tmp/dashboards/node-exporter-full-dashboard.json (ascii)"}
```

Manifests committed for reference at `files/harvester/monitoring/vllm-grafana-dashboard.yaml`
and `files/harvester/monitoring/node-exporter-full-grafana-dashboard.yaml` (exported back
out via `kubectl get configmap ... -o yaml`, stripped of cluster-generated metadata).

---

## Step 4 — Cost-comparison textfile exporter

Neither vLLM's metrics nor Node Exporter know anything about pricing — that has to be
supplied. Add a second textfile exporter on spark-e, alongside the GPU one from Step 1,
that publishes your electricity rate and a handful of reference cloud rates as
Prometheus gauges:

```bash
# /etc/dgx-cost-rates.env — edit these to match your actual electricity rate
# and whatever hyperscaler/API tiers you want to compare against
ELECTRICITY_RATE_USD_PER_KWH=0.15
CLOUD_RATE_ULTRA_USD_PER_HR=90.00   # e.g. on-demand 8x H100 instance
CLOUD_RATE_MID_USD_PER_HR=54.00     # e.g. single H100/A100 instance
CLOUD_RATE_LOW_USD_PER_HR=18.00     # e.g. equivalent hosted API spend rate
```

```bash
# /usr/local/bin/cost-textfile-exporter.sh
#!/usr/bin/env bash
set -euo pipefail
source /etc/dgx-cost-rates.env
OUT=/var/lib/node_exporter/textfile_collector/cost.prom
TMP="${OUT}.$$"

cat > "$TMP" <<EOF
# HELP dgx_electricity_rate_usd_per_kwh Configured local electricity rate
# TYPE dgx_electricity_rate_usd_per_kwh gauge
dgx_electricity_rate_usd_per_kwh ${ELECTRICITY_RATE_USD_PER_KWH}
# HELP dgx_cloud_hourly_rate_usd Reference hourly rate by comparison tier
# TYPE dgx_cloud_hourly_rate_usd gauge
dgx_cloud_hourly_rate_usd{tier="ultra"} ${CLOUD_RATE_ULTRA_USD_PER_HR}
dgx_cloud_hourly_rate_usd{tier="mid"} ${CLOUD_RATE_MID_USD_PER_HR}
dgx_cloud_hourly_rate_usd{tier="low"} ${CLOUD_RATE_LOW_USD_PER_HR}
EOF
mv "$TMP" "$OUT"
```

```bash
sudo chmod +x /usr/local/bin/cost-textfile-exporter.sh

sudo tee /etc/systemd/system/cost-textfile-exporter.timer >/dev/null <<'EOF'
[Unit]
Description=Refresh cost-comparison rates every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

sudo tee /etc/systemd/system/cost-textfile-exporter.service >/dev/null <<'EOF'
[Unit]
Description=Cost rates -> node_exporter textfile

[Service]
Type=oneshot
User=jradtke
ExecStart=/usr/local/bin/cost-textfile-exporter.sh
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cost-textfile-exporter.timer
```

These are static, hand-maintained numbers to start — since the environment isn't
actually air-gapped, a natural follow-up is swapping the static `.env` file for a script
that periodically pulls live rates from a provider pricing API (AWS Price List API,
Azure Retail Prices API, GCP Cloud Billing Catalog API) and writes the same textfile
format. Worth doing once the static version proves the dashboard is useful — not before.

---

## Step 5 — The cost-comparison panel

This is the piece that wasn't in either imported dashboard — build it as a small
standalone dashboard (or a row added to the vLLM one) using Grafana's `$__range_s`
variable, which gives the currently-selected time range in seconds. Four Stat panels,
each a Prometheus query:

**DGX energy cost over the selected range:**
```promql
(avg_over_time(dgx_gpu_power_watts[$__range]) / 1000)
  * ($__range_s / 3600)
  * dgx_electricity_rate_usd_per_kwh
```
(average kW over the range × hours in the range × $/kWh)

**Cloud tier cost over the same range** (one panel per tier, swap the label):
```promql
($__range_s / 3600) * dgx_cloud_hourly_rate_usd{tier="ultra"}
```
```promql
($__range_s / 3600) * dgx_cloud_hourly_rate_usd{tier="mid"}
```
```promql
($__range_s / 3600) * dgx_cloud_hourly_rate_usd{tier="low"}
```

Wrap these four Stat panels into a dashboard JSON and provision it the same way as Step
3 — a ConfigMap labeled `grafana_dashboard: "1"` in `cattle-dashboards`, `unit:
currencyUSD` on each panel's field config so Grafana formats them as `$1.08K` etc. Built
with a small Python script (see `files/harvester/monitoring/cost-comparison-dashboard.yaml`
for the resulting ConfigMap — the source dashboard JSON with all four panels, titled
**"DGX Spark — Cost Comparison"**, `uid: dgx-spark-cost-comparison`), then created and
labeled the same way as the other two ConfigMaps in Step 3.

Sanity-checked the four PromQL expressions directly against Prometheus with a fixed
12-hour range (`$__range` substituted with `12h`, `$__range_s` with `43200`) once vLLM
was live and the textfile exporters were producing data — numbers landed in the same
shape as the reference screenshot (Ultra $1,080 vs. its $1.08K, Mid $648 vs. $645.51, Low
$216 vs. $215.17; DGX energy came out far lower, $0.02, since spark-e was near-idle at
the time rather than under active inference load).

---

## Verification

All of the following were run and passed on 2026-07-14:

```bash
export KUBECONFIG=~/.kube/community-harvester.kubeconfig

# 1. spark-e target up in Prometheus
kubectl port-forward -n cattle-monitoring-system svc/rancher-monitoring-prometheus 9090:9090 &
curl -s 'http://localhost:9090/api/v1/targets' | python3 -c \
  "import sys,json; d=json.load(sys.stdin); [print(t['scrapePool'], t['health']) for t in d['data']['activeTargets'] if 'spark-e' in t['scrapePool']]"
# -> both sub-targets (vllm:8000, node-exporter:9100) health=up, no lastError

# 2. Textfile exporters producing metrics on spark-e
ssh -i ~/.ssh/id_ecdsa-kubernerdes jradtke@10.10.12.251 'curl -s http://localhost:9100/metrics | grep ^dgx_'
# -> dgx_gpu_power_watts, dgx_gpu_utilization_percent, dgx_gpu_temperature_celsius,
#    dgx_electricity_rate_usd_per_kwh, dgx_cloud_hourly_rate_usd{tier=...}

# 3. Grafana has all three dashboards registered
kubectl port-forward -n cattle-monitoring-system svc/rancher-monitoring-grafana 3000:80 &
ADMIN_PW=$(kubectl get secret rancher-monitoring-grafana -n cattle-monitoring-system -o jsonpath='{.data.admin-password}' | base64 -d)
curl -s -u "admin:${ADMIN_PW}" http://localhost:3000/api/search | python3 -c \
  "import sys,json; [print(i['title']) for i in json.load(sys.stdin)]"
# -> includes: vLLM Metrics, Node Exporter Full, DGX Spark — Cost Comparison
```

Grafana has no Ingress in front of it (see Open items below), so day-to-day access is
`kubectl port-forward -n cattle-monitoring-system svc/rancher-monitoring-grafana 3000:80`
then `http://localhost:3000`, or the Rancher UI's embedded monitoring proxy. Admin
password is in `secret/rancher-monitoring-grafana` (`admin-password` key).

---

## Open items

- The cost panels are validated with real data but at near-idle DGX power draw (~11W —
  spark-e wasn't running an active inference workload at verification time). Worth a
  second look once there's real request traffic against vLLM, to confirm the "DGX
  energy" number moves the way expected under load.
- No Ingress or Authentik front Harvester's Grafana yet, despite `CLAUDE.md`'s stated
  identity-provider decision — today's access is `kubectl port-forward` or Rancher's UI
  proxy. Fronting it with Authentik is a separate piece of work, not blocking this.
- Cloud comparison rates in `/etc/dgx-cost-rates.env` on spark-e are placeholder values
  (`$90`/`$54`/`$18` per hour, `$0.15`/kWh) — edit them to match your actual electricity
  rate and whatever hyperscaler/API tiers you actually want to compare against. Since the
  environment isn't actually air-gapped, a natural follow-up is swapping the static
  `.env` file for a script that periodically pulls live rates from a provider pricing API
  (AWS Price List API, Azure Retail Prices API, GCP Cloud Billing Catalog API) — worth
  doing once the static version proves the dashboard is useful, not before.
