# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is
A sovereign, air-gap-capable agentic AI platform with physical edge presence.
Built on homelab hardware. No cloud dependencies by design.

## North Star
> "A sovereign, air-gap-capable agentic AI platform with physical edge presence"

The Jetbot is the **protagonist**, not an afterthought — it does perception (camera, sensors), sends structured observations to a RAG-augmented agentic loop running against nemotron-super on the DGX Spark, and acts on results. The Harvester cluster runs orchestration. Everything stays behind the firewall.

## Hardware Stack
| Component | Role |
|-----------|------|
| NVIDIA DGX Spark | Primary inference — nemotron-super:120b via vLLM |
| Harvester cluster (3x NUC Gen13, 64GB each) | Orchestration, services, storage (RKE2/Longhorn) |
| Waveshare Jetbot (Jetson Nano) | Physical edge agent — perception + action |
| Sophos XGS88 | Perimeter — all traffic stays inside |

## Node Inventory
Domain: `homelab.kubernerdes.com` | SSH key: `~/.ssh/id_ecdsa-kubernerdes`

| Hostname | IP | User | Role |
|----------|----|------|------|
| nuc-00 | 10.10.12.10 | mansible | Harvester hub |
| nuc-01 | 10.10.12.101 | rancher | Harvester worker |
| nuc-02 | 10.10.12.102 | rancher | Harvester worker |
| nuc-03 | 10.10.12.103 | rancher | Harvester worker |
| spark-e | 10.10.12.251 | jradtke | DGX Spark — vLLM + LiteLLM |
| wheatley | 10.10.12.252 | jradtke | Dell XPS 9520 (Ubuntu 22.04) — RTX 3050 4GB — local inference |
| jarvis | 10.10.12.250 | jradtke | Asus i9 — RTX 4060 Ti 16GB — local inference |
| blackmesa | 10.10.12.247 | jradtke | Lenovo — connects to external host for inference |
| wall-e | 10.10.12.248 | jetbot | Waveshare Jetbot (JetPack 4.6) |

SSH config artifact: `files/ssh/config`

## Software Stack
| Component | Role |
|-----------|------|
| vLLM | Model serving on Spark (chosen over Ollama for throughput at 120B; NIM broken on UMA) |
| Authentik | Identity & auth — OIDC/OAuth2 for all services, deployed on RKE2/Longhorn |
| OpenWebUI (TBD) | User-facing chat interface |
| RAG layer (TBD) | Live operational state (cluster metrics, Longhorn health, NeuVector alerts) + curated docs |
| Agentic framework (TBD) | Task orchestration, tool use (kubectl, SAN, Jetbot dispatch) |

## Key Decisions (Locked)
- **vLLM over Ollama** for Spark — NIM is broken on UMA architecture; vLLM gives real throughput and batching at 120B
- **Air-gap by default** — everything must run behind the firewall; cloud egress is never assumed
- **Authentik for identity** — not ad-hoc auth; OIDC/OAuth2 for all services; deployed as a Kubernetes workload on RKE2 backed by Longhorn; FreeIPA and Keycloak were considered and rejected
- **Agentic over chat** — the interesting build is a goal-directed agentic loop with tools, not a chat wrapper

## Open Questions
- Agentic framework choice (LangChain / CrewAI / AutoGen / custom)
- RAG stack: vector DB, chunking strategy, what gets indexed (lean toward live cluster state as the corpus)
- Jetbot integration pattern (ROS2? direct Python? what triggers dispatch from the agent loop?)
- MLOps scope — only worthwhile if fine-tuning is in scope; skip if inference-only

## Project Phase
**Planning/architecture + early artifacts.** `Planning.md` contains the design discussion. `ARCHITECTURE.md` is the target for decisions as they are made. `files/` holds deployment artifacts (SSH config, etc.) built ahead of deployment.

## Conventions
- Record decisions in `ARCHITECTURE.md` as they are made, not after
- Prefer open source, self-hostable components
- Assume air-gap deployment unless explicitly noted otherwise
- Claude Code and Claude Desktop chat have no shared state — keep decisions in this repo
- Config/artifacts go in `files/` for later deployment — never written directly to the local system
