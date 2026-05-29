# ExMachina Architecture

> "A sovereign, air-gap-capable agentic AI platform with physical edge presence"

## Overview

ExMachina is a self-hosted AI stack built on homelab hardware. The design prioritizes
digital sovereignty — no cloud dependencies, air-gap capable, open source components
wherever possible. A 120B parameter model serves as the cognitive core, an agentic
framework orchestrates tasks across the infrastructure, RAG grounds the model in local
knowledge, and a physical robot acts as an edge agent in the real world.

┌─────────────────────────────────────┐
│           OpenClaw (agent)          │  ← the "brain" / agentic loop
├─────────────────────────────────────┤
│     OpenShell (policy runtime)      │  ← sandboxing, guardrails, inference routing
├─────────────────────────────────────┤
│        NemoClaw (glue layer)        │  ← onboarding, lifecycle, blueprint mgmt
├─────────────────────────────────────┤
│    vLLM + nemotron-super:120b       │  ← inference
│         DGX Spark (hardware)        │
└─────────────────────────────────────┘

---

## Hardware

| Component | Specs | Role |
|-----------|-------|------|
| NVIDIA DGX Spark | GB10 SoC, 128GB unified memory | Primary inference engine |
| NUC Gen13 (x3) | 64GB RAM each | Harvester cluster nodes |
| Dell XPS 9520 | — | Secondary/development inference |
| Waveshare Jetbot | Jetson Nano | Physical edge agent |


---

## Software Stack
| Layer | Component | Status |
|-------|-----------|--------|
| Inference | vLLM (NVFP4 nightly cu130) + nemotron-super:120b | Planned |
| Agent Runtime | NemoClaw (OpenClaw + OpenShell) | Evaluating — early preview |
| Orchestration | Harvester (Kubernetes-based HCI) | Planned |
| Agentic Framework | TBD | Open decision |
| RAG | TBD (vector DB + chunking strategy TBD) | Open decision |
| Identity & Auth | FreeIPA | Existing |
| Web UI | OpenWebUI (likely) | Planned |
| Network/Perimeter | Sophos firewall | Existing |


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

### FreeIPA for Identity
No ad-hoc auth. All services authenticate against FreeIPA. This applies to the
web UI, any APIs exposed internally, and eventually the agentic framework's
tool invocations.

### Jetbot as Physical Agent
The Jetbot is not a demo peripheral — it is a first-class agent endpoint. The
agentic framework should be able to dispatch tasks to the Jetbot (movement,
sensing, presence) as part of a workflow, not just as a standalone script.

---

## Open Decisions

- **Agentic framework**: Candidates include LangChain, CrewAI, AutoGen, LlamaIndex
  agent workflows, or a lightweight custom tool-use loop. Key criteria: air-gap
  capable, Harvester-hostable, supports FreeIPA auth, can dispatch to Jetbot.

- **RAG stack**: Vector DB choice (pgvector, Qdrant, Chroma, Milvus), chunking
  strategy, and what corpus gets indexed (infrastructure docs, runbooks, live
  cluster state, external references).

- **Jetbot integration pattern**: ROS2 vs direct Python control. What triggers
  dispatch — agentic framework task, web UI command, or autonomous sensor response?

---

## Guiding Principles

- Open source and self-hostable components preferred
- Air-gap capable by default; cloud-optional at most
- Document decisions here as they are made — this file is the source of truth
- Prefer integration over invention; don't build what exists
# Architecture

| Layer | Component | Status |
|-------|-----------|--------|
| Inference | vLLM (NVFP4 nightly cu130) + nemotron-super:120b | Planned |
| Agent Runtime | NemoClaw (OpenClaw + OpenShell) | Evaluating — early preview |
| Orchestration | Harvester (Kubernetes-based HCI) | Planned |
| Agentic Framework | TBD | Open decision |
| RAG | TBD (vector DB + chunking strategy TBD) | Open decision |
| Identity & Auth | FreeIPA | Existing |
| Web UI | OpenWebUI (likely) | Planned |
| Network/Perimeter | Sophos firewall | Existing |

## Architectural Decisions

### NemoClaw as Agent Runtime
NemoClaw (OpenClaw + NVIDIA OpenShell) provides the sandboxed agent execution layer
on the DGX Spark. OpenShell enforces out-of-process policy — security, network, and
privacy guardrails sit outside the agent, so even a compromised agent can't bypass
them. This aligns well with the air-gap-first design goal.
Note: NemoClaw is in early preview (March 2026) — APIs may change.

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
