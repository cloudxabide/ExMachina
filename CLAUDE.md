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
Currently in **planning/architecture** — no code exists yet. `Planning.md` contains the design discussion. `ARCHITECTURE.md` is the target for decisions as they are made.

## Conventions
- Record decisions in `ARCHITECTURE.md` as they are made, not after
- Prefer open source, self-hostable components
- Assume air-gap deployment unless explicitly noted otherwise
- Claude Code and Claude Desktop chat have no shared state — keep decisions in this repo
