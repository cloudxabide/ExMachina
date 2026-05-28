# Architecture

## Decisions

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
