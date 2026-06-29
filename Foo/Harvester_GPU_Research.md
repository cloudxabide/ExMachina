# Harvester GPU Research

<details>
<summary>💡 Click to view my prompt </summary>
I have the 3-node Harvester cluster deployed - and only one node has a GPU (NVIDIA RTX 4060Ti) - I'd like to ensure that a workload that needs a GPU ends up on the correct node (nuc-03).  Now - I do NOT want to preclude other work from being scheduled on that node - that would potentially be a significant waste (up to 33%).  I am also curious if there is a way to provided weights or bias for certain workloads on a node, over others.
So, based on those inputs what are your thoughts
</details>

Good framing — you've got two related but distinct goals here:

1. **GPU workloads must land on `nuc-03`** (hard requirement)
2. **Non-GPU workloads should still run on `nuc-03`** (don't waste capacity)
3. **GPU workloads should be preferred on `nuc-03` over non-GPU ones when resources are contested** (soft prioritization)

Here's how I'd think through the Kubernetes scheduling primitives that address each:

---

## Goal 1: GPU workloads → `nuc-03` (hard)

This is already mostly solved by the GPU Operator. Any pod requesting `nvidia.com/gpu: 1` will only schedule on a node that has that resource advertised. Since `nuc-03` is the only node with the GPU Operator labeling it, GPU pods are naturally constrained there — no extra nodeSelector or taint needed.

**However**, if you want to be explicit and defensive (recommended), add a `nodeAffinity` to GPU workload specs:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: feature.node.kubernetes.io/pci-10de.present
          operator: In
          values: ["true"]
```

This ensures that even if the GPU Operator label changes or a node is accidentally labeled, your intent is explicit in the workload manifest.

---

## Goal 2: Non-GPU workloads can still run on `nuc-03`

Do **not** taint `nuc-03` with `NoSchedule` for non-GPU pods. A `NoSchedule` taint would exclude all pods without a matching toleration — that's the 33% waste you want to avoid.

Instead, the default behavior (no taint) is exactly what you want. `nuc-03` participates in general scheduling like any other node. Non-GPU pods land there normally via the scheduler's bin-packing or spread logic.

---

## Goal 3: Prioritize GPU workloads over non-GPU ones on `nuc-03` when contested

This is where it gets nuanced. Kubernetes has two relevant mechanisms:

### Priority Classes (recommended)

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: gpu-workload-high
value: 1000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "High priority for GPU-bound inference workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: general-workload-normal
value: 100
globalDefault: true
preemptionPolicy: PreemptLowerPriority
```

Assign `gpu-workload-high` to your vLLM/inference pods. If `nuc-03` is under memory or CPU pressure and a GPU pod needs to schedule, the scheduler will **preempt** lower-priority pods to make room. This is the closest thing to a "weight" that Kubernetes natively provides.

### Node Affinity with Soft Preference (for non-GPU pods)

You can also tell non-GPU workloads to *prefer* other nodes, making them soft-prefer away from `nuc-03`:

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 80
      preference:
        matchExpressions:
        - key: feature.node.kubernetes.io/pci-10de.present
          operator: DoesNotExist
```

This doesn't exclude non-GPU pods from `nuc-03` — it just biases the scheduler to place them on `nuc-01`/`nuc-02` first, leaving headroom on `nuc-03` for GPU work. The `weight` value (1–100) controls how strong that preference is relative to other scoring factors.

---

## The recommended combined approach

| Mechanism | Applied to | Effect |
|---|---|---|
| `nvidia.com/gpu` resource request | GPU workloads | Hard constraint — only schedules on GPU node |
| `nodeAffinity` (required) | GPU workloads | Explicit, defensive GPU-node pinning |
| `PriorityClass: 1000` | GPU workloads | Preempts lower-priority pods if needed |
| `nodeAffinity` (preferred, weight 80) | Non-GPU workloads | Soft bias away from `nuc-03` |
| `PriorityClass: 100` (globalDefault) | Everything else | Lower preemption priority |

This gives you the behavior you described: GPU pods always land on `nuc-03`, general workloads can still run there but are nudged toward the other two nodes, and if there's a conflict, GPU workloads win via preemption.

---

## One thing to watch

Harvester's Kubernetes layer (RKE2) schedules both **VM workloads** (KubeVirt) and container workloads. KubeVirt VM pods are subject to the same scheduling rules, so if you have VMs running on `nuc-03`, they consume CPU/RAM that a GPU pod might need. You may want to assign a mid-range PriorityClass (say, 500) to critical VMs so they're not casually preempted, but still yield to GPU inference work.

---


<details>
<summary>💡 Click to view my prompt </summary>
Good set of results across official docs, practitioner blogs, and Harvester-specific material. Here's a curated breakdown organized by source quality and relevance to your setup:

---

## Official / Authoritative Sources

**Kubernetes upstream docs — GPU scheduling**
https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/

The official Kubernetes docs show using `nodeAffinity` with NFD labels like `feature.node.kubernetes.io/pci-10de.present` alongside `nvidia.com/gpu` resource limits — exactly the pattern applicable to your setup. They also cover using `kubectl label nodes` to apply custom accelerator labels for routing pods to specific GPU hardware. This is the canonical starting point.

**Harvester — VM Scheduling KB article**
https://harvesterhci.io/kb/vm-scheduling/

This one is directly relevant to your environment. Harvester doesn't schedule VMs directly — it relies on KubeVirt to create a `VirtualMachine` CR, which spawns a `VirtualMachineInstance` and then a Pod. The entire flow goes through `kube-scheduler`, which means `nodeSelector`, `affinity`, and resource requests/limits all apply normally. Harvester also exposes a default `podAntiAffinity` rule with weight 100 to spread VMs across nodes. This confirms the approach we discussed will work at the VM layer too.

**Harvester — VM creation docs (affinity UI)**
https://docs.harvesterhci.io/v1.7/vm/index/

Harvester's VM creation UI exposes a "VM Scheduling" tab that lets you configure node affinity and pod affinity/anti-affinity rules directly, without needing to hand-edit YAML — it maps to standard Kubernetes node affinity semantics.

---

## Practitioner / Production Experience

**"GPU Scheduling in Kubernetes: Lessons from Running ML Workloads"**
https://p4blo.dev/blog/kubernetes-gpu-scheduling/

One of the more honest real-world writeups. The author runs heterogeneous GPU types (A100s for training, T4s for inference) and uses the NVIDIA device plugin with custom node labels like `gpu-type`, `gpu-memory`, and `workload-class`, combined with node affinity and priority classes. They specifically flag two production pitfalls: GPU memory fragmentation (a single pod on an 8-GPU node blocking other pods), and preemption cascades where high-priority inference pods evicting training jobs caused checkpoint corruption. The second issue isn't directly relevant to your setup but is worth knowing if you add training workloads later.

**"The Ultimate Guide to GPU Provisioning in Kubernetes" (Sealos)**
https://sealos.io/blog/the-ultimate-guide-to-gpu-provisioning-and-management-in-kubernetes/

Recommends layering `PriorityClasses` for critical workloads alongside time-slicing or MIG for sharing, and enforcing `ResourceQuotas` per namespace. For multi-tenant or mixed-use clusters, the guidance is: label and taint GPU nodes, configure sharing if needed, set up priority classes per namespace/team, and add GPU monitoring via Prometheus and Grafana.

**"Running LLMs on Kubernetes: GPU Scheduling & Pitfalls"**
https://dasroot.net/posts/2026/04/running-llms-on-kubernetes-gpu-scheduling-pitfalls/

LLM-specific and recent (April 2026). Highlights that the NVIDIA GPU Operator automatically adds scheduling labels via Node Feature Discovery, and recommends using `nvidia.com/gpu.product` in node affinity rules to target specific GPU models — useful if you later add a second GPU node with different hardware and need to keep workloads on the right card.

**"Kubernetes Scheduling: Taints, Tolerations, Affinity, and Priority Classes"**
https://codingprotocols.com/blog/kubernetes-scheduling-taints-affinity-priority

Reinforces the key distinction: a toleration allows a pod to land on a tainted node, but doesn't require it — so a pod with a toleration and no `nodeSelector` may still end up on a non-GPU node. Always pair tolerations with affinity rules if you need deterministic placement. This is an easy mistake to make.

**"Kubernetes Pod Scheduling: Best Practices" (CloudBolt)**
https://www.cloudbolt.io/kubernetes-pod-scheduling/

Calls out a common anti-pattern: overly restrictive node selectors leave pods unschedulable when infrastructure changes, and relying on default priorities is dangerous — critical services should always have explicit priority classes assigned.

---

## Forward-Looking / 2026 Ecosystem

**"Kubernetes GPU Orchestration in 2026: DRA, KAI Scheduler, and Grove"**
https://www.spheron.network/blog/kubernetes-gpu-orchestration-2026/

Worth bookmarking for the ExMachina roadmap. At KubeCon Europe 2026, NVIDIA donated its Dynamic Resource Allocation (DRA) driver to CNCF. DRA addresses a core limitation of the current device plugin API: the scheduler today has no visibility into GPU memory size, compute capability, NVLink connectivity, or MIG configuration — it just sees opaque integers. Without DRA, placing a pod requiring 80GB VRAM onto the right card requires manual node labels and affinity rules. This is exactly the manual approach you're taking today — DRA will eventually make it more automatic and topology-aware.

---

## TL;DR on Sources

| Source | Most useful for |
|---|---|
| kubernetes.io/docs/tasks/manage-gpus | Ground truth on GPU scheduling primitives |
| harvesterhci.io/kb/vm-scheduling | Harvester-specific — confirms kube-scheduler is in the path |
| p4blo.dev/blog/kubernetes-gpu-scheduling | Real production ML lessons, preemption gotchas |
| dasroot.net (2026) | LLM-specific GPU scheduling, recent |
| spheron.network (2026) | DRA / future direction — what replaces manual labels |

</summary>
