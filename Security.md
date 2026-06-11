# ExMachina Security Architecture

> "Sovereign by design, zero-trust by default — every agent, tool, and service proves identity before acting."

## Overview

ExMachina combines a 120B-parameter inference engine, a multi-agent crew, live cluster tooling (kubectl, Longhorn), a vector store holding live operational state, and a physical robot with real-world actuators. The blast radius of a compromised agent or misconfigured tool in this stack is non-trivial. The air-gap perimeter eliminates most external attack vectors — but internal lateral movement, prompt injection, and identity abuse remain live threats.

This document grounds ExMachina's security posture in Anthropic's [Zero Trust for AI Agents](https://claude.com/blog/zero-trust-for-ai-agents) framework (May 2026). The Security crew role in [Agent_Roster.md](Agent_Roster.md) is the execution owner for the controls described here.

---

## Guiding Principles

- **Never trust, always verify** — internal agents and services are not implicitly trusted; identity and authorization are proved at every interaction
- **Least agency over least privilege** — permissions scoped to the task and moment of need, not the session or role
- **Air-gap as a hard invariant** — the running system never requires internet access; no control-plane egress is ever assumed
- **Physical actuators require the highest authorization bar** — Jetbot motion commands carry real-world consequences and are treated accordingly
- **Crypto identity per agent instance** — agent sessions use short-lived, task-scoped tokens, not shared API keys

---

## Shared Responsibility Model

Anthropic's framework divides AI agent security into four layers. ExMachina's ownership at each layer:

| Layer | What It Covers | ExMachina Owner |
|-------|---------------|-----------------|
| **Model** | Foundational safety alignment, refusal behavior, Constitutional AI | Anthropic (Claude), NVIDIA (nemotron-super) |
| **Harness** | System prompts, crew policies, guardrails, agent lifecycle | NemoClaw crew config; OpenShell out-of-process policy runtime |
| **Tools** | MCP servers, APIs, external integrations — what agents can call | kubectl, Qdrant RAG, LiteLLM, Jetbot dispatch API |
| **Environment** | Network, identity, secrets, deployment context | Harvester/RKE2, Sophos XGS88, Authentik, Longhorn |

The key insight: **OpenShell sits at the Harness layer and enforces policy outside the agent process** — even a fully compromised agent prompt cannot bypass guardrails, because the policy runtime is not in-scope for the agent. This is architecturally aligned with Zero Trust principles.

---

## Threat Model

Six threat classes from the Anthropic framework, mapped to ExMachina's attack surface:

| Threat | ExMachina Surface | Severity |
|--------|------------------|----------|
| **Prompt injection** | Jetbot sensor data (camera frames, LIDAR readings), RAG corpus entries, and external tool outputs are all untrusted content that could embed malicious instructions | High |
| **Tool contamination** | A compromised or malfunctioning MCP server (kubectl, Qdrant) returning crafted results to influence agent behavior | High |
| **Identity/privilege abuse** | An agent session holding standing cluster-admin when only namespace-read is needed; session tokens not expiring after task completion | High |
| **Memory poisoning** | Adversarial data written into the Qdrant corpus — live cluster state ingestion is a continuous write path and therefore an attack surface | Medium |
| **Supply chain** | Model weights, container images, and Python packages at bootstrap time; air-gap protects the running system but not the initial pull | Medium |
| **Physical actuation abuse** | Jetbot receiving unauthorized motion or camera commands — uniquely dangerous because consequences are physical and immediate | Critical |

---

## Security Controls

### Perimeter
**Date:** 2026-06-11

- Sophos XGS88 is the single choke point for all traffic; no outbound connections to inference APIs, model hubs, or cloud services at runtime
- SSH access across all nodes is key-based only (`~/.ssh/id_ecdsa-kubernerdes`); password authentication is disabled
- **Bootstrap exception:** model weights, container images, and packages are pulled through a deliberate, time-limited firewall rule; the rule is removed when the pull is complete — not left open

---

### Identity & Access
**Date:** 2026-06-11
**Decision:** Authentik (OIDC/OAuth2) is the single identity plane for all stack services. No per-service local user stores, no ad-hoc API key schemes.

**Scope:**
- All NemoClaw agent instances authenticate against Authentik; each instance receives a short-lived, task-scoped token — not a long-lived shared secret
- Jetbot (wall-e) is authenticated as a named service account, not a human user, and cannot escalate its own privileges
- LDAP outpost handles any legacy services that cannot speak OIDC natively
- LiteLLM API key is short-lived and rotated on a schedule (rotation interval TBD once deployment baseline is established)

See [ARCHITECTURE.md](ARCHITECTURE.md) — Identity Provider: Authentik decision for full rationale.

---

### Agent Trust Boundaries
**Date:** 2026-06-11

**Policy enforcement:**
- OpenShell enforces all security, network, and privacy guardrails out-of-process — the agent cannot bypass them even under adversarial prompting
- NemoClaw crew roles carry differentiated trust levels: Architect and Developer roles have broader tool grants; Implementer and Operations are more narrowly scoped
- Inter-agent messages are treated as **untrusted input**, not operator instructions — the same skepticism applied to user messages applies to messages from sibling agents

**Human-in-the-loop gates (mandatory, not optional):**
- Any `kubectl delete` or destructive cluster operation
- Any Jetbot motion command
- Any Sophos firewall rule change
- Any write to the Qdrant corpus outside of the scheduled ingestion pipeline

---

### Least Agency
**Date:** 2026-06-11

Tool access is scoped to what a specific task requires at the moment it is requested — not to what the agent role might ever need:

| Tool | Default Grant | Elevated Grant (requires explicit request) |
|------|--------------|---------------------------------------------|
| kubectl | Read-only, namespace-scoped | Specific verbs (apply, delete) for a named namespace, time-bounded |
| Qdrant | Read-only | Write access for RAG ingestion pipeline runs only |
| LiteLLM / vLLM | Inference requests | Admin API (model management, config) |
| Jetbot dispatch | Status queries | Motion commands (requires human-in-the-loop confirmation) |

---

### Physical Edge
**Date:** 2026-06-11

The Jetbot (wall-e) occupies a special threat category: it is the only stack component whose actions have physical, real-world consequences.

- **Sensor data is untrusted input** — camera frames, LIDAR readings, and IMU data are sanitized before injection into agent context; they are treated as external content, not operator instructions
- **Command channel is unidirectional** — orchestrator → Jetbot only; wall-e cannot initiate actions against the cluster or other services
- **Motion commands require two confirmations** — the orchestrating agent must request the action, and a human-in-the-loop gate must confirm before dispatch
- **Emergency stop takes precedence** — hardware kill switch on the Jetbot overrides any software command with no possible software bypass

---

### Secrets Management
**Date:** 2026-06-11

- No secrets or credentials are committed to this repository — `files/` holds deployment configs only
- At-rest encryption: Authentik bootstrap credentials and service secrets are stored in Kubernetes Secrets with RKE2 etcd encryption enabled
- The strategy for secrets beyond K8s Secrets (HashiCorp Vault, Sealed Secrets, External Secrets Operator) is an open decision — see below

---

### Audit & Observability
**Date:** 2026-06-11

Visibility layers:
- **NeuVector** — container runtime security policies define behavioral baselines; alerts are fed into the Qdrant RAG corpus as live operational state, making them available to the agent loop
- **Authentik audit log** — captures all authentication and authorization events across the stack
- **Agent tool call log** — every tool invocation is logged with: agent identity, tool name, inputs (sanitized), outputs (sanitized), and timestamp
- **Sophos XGS88** — perimeter traffic logs; primary signal for unexpected egress attempts

Centralized log aggregation target is an open decision (see below). Loki/Grafana is preferred given the existing Kubernetes footprint.

---

## Open Security Decisions

- **Secrets management beyond K8s Secrets**: HashiCorp Vault (full-featured, operationally heavy), Sealed Secrets (GitOps-friendly, simpler), or External Secrets Operator (pulls from external store — less relevant in air-gap). Decision deferred until Harvester cluster deployment baseline is stable.

- **Centralized log aggregation**: Loki + Grafana is the preferred direction (consistent with Kubernetes ecosystem; lower resource footprint than Elasticsearch). Not yet deployed.

- **Incident response playbook**: No formal playbook exists. Minimum viable: what does the Security crew do when NeuVector fires an alert? Who is paged? What is the blast radius assessment process?

- **Certificate management**: cert-manager with a self-signed internal CA is the likely path for internal TLS. Manual rotation is the fallback. Decision deferred until service mesh / ingress layer is defined.

- **Audit log retention policy**: No retention policy defined. Required before production workloads run.

- **Jetbot integration pattern** (security implications): ROS2 vs. direct Python + MQTT affects the command channel authentication model. See [ARCHITECTURE.md](ARCHITECTURE.md) Open Decisions.

---

## References

- [Anthropic — Zero Trust for AI Agents](https://claude.com/blog/zero-trust-for-ai-agents) (eBook, May 2026)
- [Agent_Roster.md](Agent_Roster.md) — Security crew role definition and responsibilities
- [ARCHITECTURE.md](ARCHITECTURE.md) — Locked decisions: Authentik, vLLM, OpenShell, air-gap, Qdrant, NemoClaw
- NeuVector — container runtime security
- RKE2 security hardening guide
- OWASP — Least Agency principle (co-developed with Anthropic)
