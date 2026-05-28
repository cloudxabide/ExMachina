# ExMachina

## What This Is
A sovereign, air-gap-capable agentic AI platform with physical edge presence.
Built on homelab hardware. No cloud dependencies by design.

## North Star
A self-hosted AI stack where a 120B reasoning model serves as the cognitive core,
an agentic framework orchestrates tasks, RAG grounds it in local knowledge,
and a physical robot (Jetbot) acts as an edge agent in the real world.

## Stack
| Component | Role |
|-----------|------|
| NVIDIA DGX Spark | Primary inference (nemotron-super:120b via vLLM) |
| Harvester cluster (3x NUC Gen13, 64GB each) | Orchestration, services, storage |
| Waveshare Jetbot | Physical edge agent |
| FreeIPA | Identity & auth |
| OpenWebUI (TBD) | User-facing chat interface |
| RAG layer (TBD) | Grounds model in local docs/state |
| Agentic framework (TBD) | Task orchestration, tool use, Jetbot dispatch |

## Key Decisions
- vLLM over Ollama for Spark (NIM is broken on UMA architecture)
- Air-gap capable: everything must be runnable behind the firewall
- FreeIPA for identity (not ad-hoc auth)
- Agentic framework not yet selected — this is an open decision

## Open Questions
- Agentic framework choice (LangChain / CrewAI / AutoGen / custom)
- RAG stack (vector DB, chunking strategy, what gets indexed)
- Jetbot integration pattern (ROS2? direct Python? what triggers dispatch?)

## Conventions
- Document decisions in ARCHITECTURE.md as they are made
- Prefer open source, self-hostable components
- Assume air-gap deployment unless explicitly noted otherwise
