# ExMachina Architecture

> "A sovereign, air-gap-capable agentic AI platform with physical edge presence"

## Overview

ExMachina is a self-hosted AI stack built on homelab hardware. The design prioritizes
digital sovereignty — no cloud dependencies, air-gap capable, open source components
wherever possible. A 120B parameter model serves as the cognitive core, an agentic
framework orchestrates tasks across the infrastructure, RAG grounds the model in local
knowledge, and a physical robot acts as an edge agent in the real world.

<pre>
┌─────────────────────────────────────┐
│           OpenClaw (agent)          │  ← the "brain" / agentic loop
├─────────────────────────────────────┤
│     OpenShell (policy runtime)      │  ← sandboxing, guardrails, inference routing
├─────────────────────────────────────┤
│        NemoClaw (glue layer)        │  ← onboarding, lifecycle, blueprint mgmt
├─────────────────────────────────────┤
│  vLLM + nemotron-3-super120b:a12b   │  ← inference (MoE: 120B total / 12B active)
│         DGX Spark (hardware)        │
└─────────────────────────────────────┘
</pre>

---

## Hardware

| Component | Hostname | IP | Specs | Role |
|-----------|----------|----|-------|------|
| NVIDIA DGX Spark | spark-e.homelab.kubernerdes.com | 10.10.12.251 | GB10 SoC, 128GB unified memory | Primary inference engine |
| NUC Gen13 (x3) | — | — | 64GB RAM each | Harvester cluster nodes |
| Dell XPS 9520 | wheatley.homelab.kubernerdes.com | 10.10.12.252 | — | Secondary/dev node (openSUSE Tumbleweed) |
| Waveshare Jetbot | wall-e.homelab.kubernerdes.com | 10.10.12.248 | Jetson Nano | Physical edge agent (deferred) |


---

## Software Stack
| Layer | Component | Status |
|-------|-----------|--------|
| Inference | vLLM + nemotron-3-super120b:a12b (120B total / 12B active MoE) | **Running** on spark-e |
| Inference proxy | LiteLLM on port 40000 (OpenAI-compatible API) | **Running** on spark-e |
| Agent Runtime | NemoClaw (OpenClaw + OpenShell) | Locked — early preview |
| Orchestration | Harvester (Kubernetes-based HCI) | Planned |
| Agentic Framework | OpenClaw (NemoClaw suite) | Locked |
| RAG — Vector DB | Qdrant (K8s workload on Harvester) | Locked |
| RAG — Corpus | Live cluster state + curated docs + Jetbot sensor data | Locked |
| Identity & Auth | Authentik (OIDC/OAuth2) on RKE2/Longhorn | Locked |
| Web UI | OpenWebUI (likely) | Planned |
| Network/Perimeter | Sophos XGS88 | Existing |


---

## Key Architectural Decisions

### Inference: vLLM over Ollama
NIM is not viable on the DGX Spark due to its UMA (unified memory architecture) —
NIM requires discrete GPU/CPU memory separation. vLLM with the NVFP4 nightly cu130
build is the correct path for serving nemotron-super:120b at this weight class.
Ollama is convenient but not optimized for 120B inference.

### NemoClaw as Agent Runtime
NemoClaw (OpenClaw + NVIDIA OpenShell) provides the sandboxed agent execution layer
on the DGX Spark. OpenShell enforces out-of-process policy — security, network, and
privacy guardrails sit outside the agent, so even a compromised agent can't bypass
them. This aligns well with the air-gap-first design goal.
Note: NemoClaw is in early preview (March 2026) — APIs may change.

### Air-gap First
All components must be runnable entirely behind the firewall. External dependencies
(pip packages, container images, model weights) are acceptable at setup time but
the running system must not require internet access.

### Identity Provider: Authentik
**Date:** 2026-05-28 — Authentik replaces FreeIPA as the identity provider.
No ad-hoc auth. All services authenticate against Authentik via OIDC/OAuth2. This applies to the
web UI, any APIs exposed internally, and the agentic framework's tool invocations.
See detailed rationale in Key Architectural Decisions below.

### Jetbot as Physical Agent
The Jetbot is not a demo peripheral — it is a first-class agent endpoint. The
agentic framework should be able to dispatch tasks to the Jetbot (movement,
sensing, presence) as part of a workflow, not just as a standalone script.

---

## Open Decisions

- **Jetbot integration pattern**: Deferred until DGX Spark + OpenClaw stack is
  operational. ROS2 on Jetson Nano (JetPack 4.6 / Ubuntu 18.04) is Tier 3 /
  build-from-source; direct Python + MQTT is the likely path. Revisit once inference
  layer is running — or if hardware is upgraded to Jetson Orin Nano / Xavier NX.

- **Web UI**: OpenWebUI is the likely choice but not yet locked.

- **MLOps scope**: Only relevant if fine-tuning enters scope; skip if inference-only.

---

## Guiding Principles

- Open source and self-hostable components preferred
- Air-gap capable by default; cloud-optional at most
- Document decisions here as they are made — this file is the source of truth
- Prefer integration over invention; don't build what exists

---

### Identity Provider: Authentik (over FreeIPA / Keycloak)
**Date:** 2026-05-28
**Decision:** Use Authentik as the identity provider for the entire stack.
**Deployment:** Kubernetes workload on the RKE2 cluster, backed by Longhorn for persistence.
**Protocols:** OIDC/OAuth2 for modern services; LDAP via Authentik outpost for anything legacy.

**Rationale:**
- FreeIPA is designed around RHEL-enrolled machines and Kerberos — the wrong fit for a Kubernetes-native AI service stack where services want OIDC/OAuth2
- Keycloak covers the same ground but is heavier (Java, higher memory) and more complex to operate
- Authentik is container-native, actively developed, and covers the protocols this stack actually needs (OIDC for OpenWebUI, agentic framework, vLLM API, Jetbot callback auth)

**Scope:** All stack services authenticate against Authentik — no per-service local user stores, no ad-hoc API key schemes.

---

### RAG: Qdrant as Vector Store
**Date:** 2026-05-29
**Decision:** Use Qdrant as the vector database for the RAG layer.
**Deployment:** Kubernetes workload on Harvester (Helm chart, Longhorn for persistence).

**Rationale:**
- Purpose-built vector DB — better filtering, payload indexing, and performance than pgvector at scale
- Rust-based, low memory overhead, self-hostable K8s workload
- Active development; good Python client that integrates cleanly with LlamaIndex/OpenClaw

**Corpus (locked):**
1. Live cluster state — Harvester metrics, RKE2 workload status, Longhorn health, NeuVector alerts (continuously ingested)
2. Curated docs / runbooks — operational runbooks, architecture docs, stack vendor docs
3. Jetbot sensor data — structured observations from the Jetbot (camera descriptions, sensor readings) as episodic memory

---

### Agentic Framework: OpenClaw (NemoClaw suite)
**Date:** 2026-05-29
**Decision:** OpenClaw is the agentic loop / "brain" of the stack.
**Deployment:** Runs on DGX Spark alongside vLLM; OpenShell provides the out-of-process policy layer.

**Rationale:**
- Already selected as the Agent Runtime — OpenClaw IS the agentic framework in the NemoClaw architecture
- OpenShell enforces guardrails outside the agent process — aligned with air-gap-first and sovereignty goals
- Tight integration with vLLM and nemotron-super on the same hardware

**Risk:** NemoClaw is in early preview (March 2026) — APIs may change. Monitor upstream.
