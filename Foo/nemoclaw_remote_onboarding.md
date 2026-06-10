# NemoClaw Onboarding to remote NVIDIA DGX

A few nuanced things (like adding "--no-gpu")

<pre>
jradtke@wheatley:~> nemoclaw onboard --fresh --no-gpu

  NemoClaw Onboarding
  ===================

  [1/8] Preflight checks
  ──────────────────────────────────────────────────
  ✓ Docker is running
  ✓ Docker can start bridge containers
  ✓ Container DNS resolution works
  ✓ Container runtime: docker
  ✓ Container runtime resources: 20 vCPU / 31.0 GiB
  ✓ openshell CLI: openshell 0.0.44
  ✓ Port 8080 already owned by healthy NemoClaw runtime (OpenShell gateway)
  ✓ NVIDIA GPU detected (NVIDIA GeForce RTX 3050 Ti Laptop GPU, 4096 MB)
  ⓘ Local NIM unavailable — GPU VRAM too small
  ✓ Sandbox GPU: disabled by configuration
  ✓ Memory OK: 31758 MB RAM + 2048 MB swap

  [2/8] Starting OpenShell gateway
  ──────────────────────────────────────────────────
  [reuse] Skipping gateway (running)
  Reusing healthy NemoClaw gateway.

  [3/8] Configuring inference provider
  ──────────────────────────────────────────────────
  Detected local inference option: Ollama


  Inference options:
    1) NVIDIA Endpoints
    2) OpenAI
    3) Other OpenAI-compatible endpoint
    4) Anthropic
    5) Other Anthropic-compatible endpoint
    6) Google Gemini
    7) Local Ollama (localhost:11434) — running (suggested)
    8) Model Router (experimental)

  Choose [1]: 3
  OpenAI-compatible base URL (e.g., https://openrouter.ai): http://10.10.12.251:11434/v1
  Other OpenAI-compatible endpoint API key: *****

  Credential staged. Onboarding will register it with the OpenShell gateway.

  Other OpenAI-compatible endpoint model []: nemotron-3-super:120b
  Chat Completions API available — OpenClaw will use openai-completions.
  Using Other OpenAI-compatible endpoint with model: nemotron-3-super:120b
  Sandbox name (1-63 characters, lowercase, starts with a letter, letters/numbers/internal hyphens only, ends with letter/number) [my-assistant]: spark-remote

  ──────────────────────────────────────────────────
  Review configuration
  ──────────────────────────────────────────────────
  Provider:      compatible-endpoint
  Model:         nemotron-3-super:120b
  API key:       configured for OpenShell gateway registration
  Web search:    disabled
  Managed tools: none
  Messaging:     none
  Sandbox name:  spark-remote
  Note:          Sandbox build typically takes 3–8 minutes on this host.
  ──────────────────────────────────────────────────
  Web search and messaging channels will be prompted next.
  Apply this configuration? [Y/n]: Y

  [4/8] Setting up inference provider
  ──────────────────────────────────────────────────
✓ Active gateway set to 'nemoclaw'
✓ Updated provider compatible-endpoint
Gateway inference configured:

  Route: inference.local
  Provider: compatible-endpoint
  Model: nemotron-3-super:120b
  Version: 4
  Timeout: 180s
  ✓ Inference smoke passed: compatible-endpoint / nemotron-3-super:120b
  ✓ Inference route set: compatible-endpoint / nemotron-3-super:120b
  Enable Brave Web Search? [y/N]: y

  Get your Brave Search API key from: https://brave.com/search/api/

  Brave Search API key: ****
  Brave Search API key validation failed.
  HTTP 422: {"error":{"code":"SUBSCRIPTION_TOKEN_INVALID","detail":"The provided subscription token is invalid.","meta":{"component":"authentication"},"status":422},"type":"ErrorResponse"}
  Brave Search validation did not succeed.
  Type 'retry', 'skip', or 'exit' [retry]: skip
  Skipping Brave Web Search setup.


  [5/8] Messaging channels
  ──────────────────────────────────────────────────

  Available messaging channels:
    [1] ○ telegram — Telegram bot messaging
    [2] ○ discord — Discord bot messaging
    [3] ○ wechat — WeChat (personal) bot messaging
    [4] ● slack — Slack bot messaging
    [5] ○ whatsapp — WhatsApp Web messaging (QR pairing)

  Press 1-5 to toggle, Enter when done (none selected skips):

  Slack API → Your Apps → OAuth & Permissions → Bot User OAuth Token (xoxb-...).
  Slack Bot Token: ***********************************************************
  ✓ slack token saved

  Slack API → Your Apps → Basic Information → App-Level Tokens (xapp-...).
  Slack App Token (Socket Mode): **************************************************************************************************
  ✓ slack app token saved
  In Slack, open each allowed human user's profile -> More -> Copy member ID. Enter one or more comma-separated member IDs, not the app or bot user ID. Member IDs look like U01ABC2DEF3.
  Slack Member IDs (comma-separated allowlist): U01ABC2DEF3
  ✓ slack allowed IDs saved
  Optional: enter comma-separated Slack channel IDs where the bot may answer @mentions. Channel IDs look like C012AB3CD.
  Slack Channel IDs (comma-separated allowlist): C012AB3CD
  ✓ slack channel IDs saved


  Resource profiles:
    1) creator (cpu=50%, ram=50%)
    2) gamer (cpu=25%, ram=25%)
    3) game-developer (cpu=60%, ram=60%)
    4) developer (cpu=75%, ram=75%)
    5) custom (enter values manually)
    6) No profile (OpenShell defaults)
  Choose [6]: 4
  Using profile: developer

  [6/8] Creating sandbox
  ──────────────────────────────────────────────────
  Sandbox 'spark-remote' already exists as unknown.
  NemoClaw is onboarding OpenClaw for this sandbox name.
  Side-by-side agents are supported, but each sandbox name has one agent type.
  Delete and recreate 'spark-remote' as OpenClaw? [y/N]: y
  Sandbox 'spark-remote' exists as unknown — recreating as OpenClaw.
  Backing up workspace state before recreating sandbox...
  ✓ State backed up (13 directories, 0 files)
  Deleting and recreating sandbox 'spark-remote'...
✓ Deleted sandbox spark-remote
  Including policy preset(s) at sandbox boot: slack
✓ Deleted provider spark-remote-slack-bridge
✓ Created provider spark-remote-slack-bridge
✓ Deleted provider spark-remote-slack-app
✓ Created provider spark-remote-slack-app
  Creating sandbox 'spark-remote' (this takes a few minutes on first run)...
  Pinning base image to sha256:10433a8cd2f2...
  Building sandbox image...
  Building image openshell/sandbox-from:1780841875 from /tmp/nemoclaw-build-6DbZdd/Dockerfile
  Step 1/80 : ARG BASE_IMAGE=ghcr.io/nvidia/nemoclaw/sandbox-base@sha256:10433a8cd2f2b809dd0fdf983514679e04c0f8aa1ff5bbff675029046033b108
  Step 1/80 completed in 0.0s (ARG BASE_IMAGE=ghcr.io/nvidia/nemoclaw/sandbox-base@sha256:10433a8cd2f2b809dd0fdf983514679e04c0f8aa1ff5bbff6750290460...
  Step 2/80 : FROM node:22-trixie-slim@sha256:2d9f5c76c8f4dd36e8f253bee5d828a83a6c09f36188f0b0414325232e0b175d AS builder
  Step 2/80 completed in 0.0s (FROM node:22-trixie-slim@sha256:2d9f5c76c8f4dd36e8f253bee5d828a83a6c09f36188f0b0414325232e0b175d AS builder)
  Step 3/80 : ENV NPM_CONFIG_AUDIT=false     NPM_CONFIG_FUND=false     NPM_CONFIG_UPDATE_NOTIFIER=false     NPM_CONFIG_FETCH_RETRIES=5     NPM_CONFI...
  Step 3/80 completed in 0.0s (ENV NPM_CONFIG_AUDIT=false NPM_CONFIG_FUND=false NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FETCH_RETRIES=5 NPM_CONF...
  Step 4/80 : COPY nemoclaw/package.json nemoclaw/package-lock.json nemoclaw/tsconfig.json /opt/nemoclaw/
  Step 4/80 completed in 0.0s (COPY nemoclaw/package.json nemoclaw/package-lock.json nemoclaw/tsconfig.json /opt/nemoclaw/)
  Step 5/80 : COPY nemoclaw/src/ /opt/nemoclaw/src/
  Step 5/80 completed in 0.0s (COPY nemoclaw/src/ /opt/nemoclaw/src/)
  Step 6/80 : WORKDIR /opt/nemoclaw
  Step 6/80 completed in 0.0s (WORKDIR /opt/nemoclaw)
  Step 7/80 : RUN npm ci && npm run build
  Step 7/80 completed in 0.0s (RUN npm ci && npm run build)
  Step 8/80 : FROM ${BASE_IMAGE}
  Step 8/80 completed in 0.0s (FROM ${BASE_IMAGE})
  Step 9/80 : ARG OPENCLAW_VERSION=2026.5.22
  Step 9/80 completed in 0.0s (ARG OPENCLAW_VERSION=2026.5.22)
  Step 10/80 : ARG OPENCLAW_2026_5_22_INTEGRITY=sha512-m+zgBELGbCHjWB1IWF5WSWNPr480cMKOMff2OF72c8A0AMD4hC/9+qwYtzjYmGkETcffnB711JymlVsQnh2Tow==
  Step 10/80 completed in 0.0s (ARG OPENCLAW_2026_5_22_INTEGRITY=sha512-m+zgBELGbCHjWB1IWF5WSWNPr480cMKOMff2OF72c8A0AMD4hC/9+qwYtzjYmGkETcffnB711Jym...
  Step 11/80 : RUN set -eu;     apt-mark manual procps e2fsprogs 2>/dev/null || true;     (apt-get remove --purge -y gcc gcc-12 g++ g++-12 cpp cpp-1...
  Step 11/80 completed in 0.0s (RUN set -eu; apt-mark manual procps e2fsprogs 2>/dev/null || true; (apt-get remove --purge -y gcc gcc-12 g++ g++-12 ...
  Step 12/80 : COPY --from=builder /opt/nemoclaw/dist/ /opt/nemoclaw/dist/
  Step 12/80 completed in 0.0s (COPY --from=builder /opt/nemoclaw/dist/ /opt/nemoclaw/dist/)
  Step 13/80 : COPY nemoclaw/openclaw.plugin.json /opt/nemoclaw/
  Step 13/80 completed in 0.0s (COPY nemoclaw/openclaw.plugin.json /opt/nemoclaw/)
  Step 14/80 : COPY nemoclaw/package.json nemoclaw/package-lock.json /opt/nemoclaw/
  Step 14/80 completed in 0.0s (COPY nemoclaw/package.json nemoclaw/package-lock.json /opt/nemoclaw/)
  Step 15/80 : COPY nemoclaw-blueprint/ /opt/nemoclaw-blueprint/
  Step 15/80 completed in 0.0s (COPY nemoclaw-blueprint/ /opt/nemoclaw-blueprint/)
  Step 16/80 : RUN chmod -R a+rX /opt/nemoclaw /opt/nemoclaw-blueprint/
  Step 16/80 completed in 0.0s (RUN chmod -R a+rX /opt/nemoclaw /opt/nemoclaw-blueprint/)
  Step 17/80 : WORKDIR /opt/nemoclaw
  Step 17/80 completed in 0.0s (WORKDIR /opt/nemoclaw)
  Step 18/80 : ENV NPM_CONFIG_AUDIT=false     NPM_CONFIG_FUND=false     NPM_CONFIG_UPDATE_NOTIFIER=false     NPM_CONFIG_FETCH_RETRIES=5     NPM_CONF...
  Step 18/80 completed in 0.0s (ENV NPM_CONFIG_AUDIT=false NPM_CONFIG_FUND=false NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FETCH_RETRIES=5 NPM_CON...
  Step 19/80 : RUN npm ci --omit=dev
  Step 19/80 completed in 0.0s (RUN npm ci --omit=dev)
  Step 20/80 : COPY scripts/patch-openclaw-tool-catalog.js /usr/local/lib/nemoclaw/patch-openclaw-tool-catalog.js
  Step 20/80 completed in 0.0s (COPY scripts/patch-openclaw-tool-catalog.js /usr/local/lib/nemoclaw/patch-openclaw-tool-catalog.js)
  Step 21/80 : COPY scripts/patch-openclaw-chat-send.js /usr/local/lib/nemoclaw/patch-openclaw-chat-send.js
  Step 21/80 completed in 0.0s (COPY scripts/patch-openclaw-chat-send.js /usr/local/lib/nemoclaw/patch-openclaw-chat-send.js)
  Step 22/80 : RUN chmod 755 /usr/local/lib/nemoclaw/patch-openclaw-tool-catalog.js         /usr/local/lib/nemoclaw/patch-openclaw-chat-send.js
  Step 22/80 completed in 0.0s (RUN chmod 755 /usr/local/lib/nemoclaw/patch-openclaw-tool-catalog.js /usr/local/lib/nemoclaw/patch-openclaw-chat-sen...
  Step 23/80 : RUN set -eu;     echo "$OPENCLAW_VERSION" | grep -qxE '[0-9]+(\.[0-9]+)*'         || { echo "ERROR: OPENCLAW_VERSION='$OPENCLAW_VERSI...
  Step 23/80 completed in 0.0s (RUN set -eu; echo "$OPENCLAW_VERSION" | grep -qxE '[0-9]+(\.[0-9]+)*' || { echo "ERROR: OPENCLAW_VERSION='$OPENCLAW_...
  Step 24/80 : RUN set -eu;     OC_DIST=/usr/local/lib/node_modules/openclaw/dist;     OC_VERSION="$(openclaw --version 2>/dev/null | awk '{print $2...
  Step 24/80 completed in 0.0s (RUN set -eu; OC_DIST=/usr/local/lib/node_modules/openclaw/dist; OC_VERSION="$(openclaw --version 2>/dev/null | awk '...
  Step 25/80 : RUN node /usr/local/lib/nemoclaw/patch-openclaw-chat-send.js     /usr/local/lib/node_modules/openclaw/dist
  Step 25/80 completed in 0.0s (RUN node /usr/local/lib/nemoclaw/patch-openclaw-chat-send.js /usr/local/lib/node_modules/openclaw/dist)
  Step 26/80 : RUN node /usr/local/lib/nemoclaw/patch-openclaw-tool-catalog.js     /usr/local/lib/node_modules/openclaw/dist
  Step 26/80 completed in 0.0s (RUN node /usr/local/lib/nemoclaw/patch-openclaw-tool-catalog.js /usr/local/lib/node_modules/openclaw/dist)
  Step 27/80 : RUN mkdir -p /sandbox/.nemoclaw/blueprints/0.1.0     && cp -r /opt/nemoclaw-blueprint/* /sandbox/.nemoclaw/blueprints/0.1.0/
  Step 27/80 completed in 0.0s (RUN mkdir -p /sandbox/.nemoclaw/blueprints/0.1.0 && cp -r /opt/nemoclaw-blueprint/* /sandbox/.nemoclaw/blueprints/0....
  Step 28/80 : COPY scripts/lib/sandbox-init.sh /usr/local/lib/nemoclaw/sandbox-init.sh
  Step 28/80 completed in 0.0s (COPY scripts/lib/sandbox-init.sh /usr/local/lib/nemoclaw/sandbox-init.sh)
  Step 29/80 : COPY scripts/nemoclaw-start.sh /usr/local/bin/nemoclaw-start
  Step 29/80 completed in 0.0s (COPY scripts/nemoclaw-start.sh /usr/local/bin/nemoclaw-start)
  Step 30/80 : COPY nemoclaw-blueprint/scripts/*.js /usr/local/lib/nemoclaw/preloads/
  Step 30/80 completed in 0.0s (COPY nemoclaw-blueprint/scripts/*.js /usr/local/lib/nemoclaw/preloads/)
  Step 31/80 : COPY scripts/codex-acp-wrapper.sh /usr/local/bin/nemoclaw-codex-acp
  Step 31/80 completed in 0.0s (COPY scripts/codex-acp-wrapper.sh /usr/local/bin/nemoclaw-codex-acp)
  Step 32/80 : COPY scripts/generate-openclaw-config.py /usr/local/lib/nemoclaw/generate-openclaw-config.py
  Step 32/80 completed in 0.0s (COPY scripts/generate-openclaw-config.py /usr/local/lib/nemoclaw/generate-openclaw-config.py)
  Step 33/80 : COPY scripts/openclaw-build-messaging-plugins.py /usr/local/lib/nemoclaw/openclaw-build-messaging-plugins.py
  Step 33/80 completed in 0.0s (COPY scripts/openclaw-build-messaging-plugins.py /usr/local/lib/nemoclaw/openclaw-build-messaging-plugins.py)
  Step 34/80 : COPY scripts/seed-wechat-accounts.py /usr/local/lib/nemoclaw/seed-wechat-accounts.py
  Step 34/80 completed in 0.0s (COPY scripts/seed-wechat-accounts.py /usr/local/lib/nemoclaw/seed-wechat-accounts.py)
  Step 35/80 : COPY nemoclaw-blueprint/openclaw-plugins/ /usr/local/share/nemoclaw/openclaw-plugins/
  Step 35/80 completed in 0.0s (COPY nemoclaw-blueprint/openclaw-plugins/ /usr/local/share/nemoclaw/openclaw-plugins/)
  Step 36/80 : RUN chmod 755 /usr/local/bin/nemoclaw-start /usr/local/bin/nemoclaw-codex-acp         /usr/local/lib/nemoclaw/sandbox-init.sh        ...
  Step 36/80 completed in 0.0s (RUN chmod 755 /usr/local/bin/nemoclaw-start /usr/local/bin/nemoclaw-codex-acp /usr/local/lib/nemoclaw/sandbox-init.s...
  Step 37/80 : ARG NEMOCLAW_MODEL=nemotron-3-super:120b
  Step 37/80 completed in 0.0s (ARG NEMOCLAW_MODEL=nemotron-3-super:120b)
  Step 38/80 : ARG NEMOCLAW_PROVIDER_KEY=inference
  Step 38/80 completed in 0.0s (ARG NEMOCLAW_PROVIDER_KEY=inference)
  Step 39/80 : ARG NEMOCLAW_PRIMARY_MODEL_REF=inference/nemotron-3-super:120b
  Step 39/80 completed in 0.0s (ARG NEMOCLAW_PRIMARY_MODEL_REF=inference/nemotron-3-super:120b)
  Step 40/80 : ARG CHAT_UI_URL=http://127.0.0.1:18789
  Step 40/80 completed in 0.0s (ARG CHAT_UI_URL=http://127.0.0.1:18789)
  Step 41/80 : ARG NEMOCLAW_INFERENCE_BASE_URL=https://inference.local/v1
  Step 41/80 completed in 0.0s (ARG NEMOCLAW_INFERENCE_BASE_URL=https://inference.local/v1)
  Step 42/80 : ARG NEMOCLAW_INFERENCE_API=openai-completions
  Step 42/80 completed in 0.0s (ARG NEMOCLAW_INFERENCE_API=openai-completions)
  Step 43/80 : ARG NEMOCLAW_CONTEXT_WINDOW=131072
  Step 43/80 completed in 0.0s (ARG NEMOCLAW_CONTEXT_WINDOW=131072)
  Step 44/80 : ARG NEMOCLAW_MAX_TOKENS=4096
  Step 44/80 completed in 0.0s (ARG NEMOCLAW_MAX_TOKENS=4096)
  Step 45/80 : ARG NEMOCLAW_REASONING=false
  Step 45/80 completed in 0.0s (ARG NEMOCLAW_REASONING=false)
  Step 46/80 : ARG NEMOCLAW_INFERENCE_INPUTS=text
  Step 46/80 completed in 0.0s (ARG NEMOCLAW_INFERENCE_INPUTS=text)
  Step 47/80 : ARG NEMOCLAW_AGENT_TIMEOUT=600
  Step 47/80 completed in 0.0s (ARG NEMOCLAW_AGENT_TIMEOUT=600)
  Step 48/80 : ARG NEMOCLAW_AGENT_HEARTBEAT_EVERY=
  Step 48/80 completed in 0.0s (ARG NEMOCLAW_AGENT_HEARTBEAT_EVERY=)
  Step 49/80 : ARG NEMOCLAW_INFERENCE_COMPAT_B64=eyJzdXBwb3J0c1N0b3JlIjpmYWxzZX0=
  Step 49/80 completed in 0.0s (ARG NEMOCLAW_INFERENCE_COMPAT_B64=eyJzdXBwb3J0c1N0b3JlIjpmYWxzZX0=)
  Step 50/80 : ARG NEMOCLAW_MESSAGING_CHANNELS_B64=WyJzbGFjayJd
  Step 50/80 completed in 0.0s (ARG NEMOCLAW_MESSAGING_CHANNELS_B64=WyJzbGFjayJd)
  Step 51/80 : ARG NEMOCLAW_MESSAGING_ALLOWED_IDS_B64=eyJzbGFjayI6WyJVMEI3MDVHUlNQTSJdfQ==
  Step 51/80 completed in 0.0s (ARG NEMOCLAW_MESSAGING_ALLOWED_IDS_B64=eyJzbGFjayI6WyJVMEI3MDVHUlNQTSJdfQ==)
  Step 52/80 : ARG NEMOCLAW_DISCORD_GUILDS_B64=e30=
  Step 52/80 completed in 0.0s (ARG NEMOCLAW_DISCORD_GUILDS_B64=e30=)
  Step 53/80 : ARG NEMOCLAW_TELEGRAM_CONFIG_B64=e30=
  Step 53/80 completed in 0.0s (ARG NEMOCLAW_TELEGRAM_CONFIG_B64=e30=)
  Step 54/80 : ARG NEMOCLAW_WECHAT_CONFIG_B64=e30=
  Step 54/80 completed in 0.0s (ARG NEMOCLAW_WECHAT_CONFIG_B64=e30=)
  Step 55/80 : ARG NEMOCLAW_SLACK_CONFIG_B64=eyJhbGxvd2VkQ2hhbm5lbHMiOlsiQzBCN0E1WUZWQjYiXX0=
  Step 55/80 completed in 0.0s (ARG NEMOCLAW_SLACK_CONFIG_B64=eyJhbGxvd2VkQ2hhbm5lbHMiOlsiQzBCN0E1WUZWQjYiXX0=)
  Step 56/80 : ARG NEMOCLAW_DISABLE_DEVICE_AUTH=1
  Step 56/80 completed in 0.0s (ARG NEMOCLAW_DISABLE_DEVICE_AUTH=1)
  Step 57/80 : ARG NEMOCLAW_BUILD_ID=1780841875610
  Step 57/80 completed in 1.6s (ARG NEMOCLAW_BUILD_ID=1780841875610)
  Step 58/80 : ARG NEMOCLAW_DARWIN_VM_COMPAT=0
  Step 58/80 completed in 1.6s (ARG NEMOCLAW_DARWIN_VM_COMPAT=0)
  Step 59/80 : ARG NEMOCLAW_PROXY_HOST=10.200.0.1
  Step 59/80 completed in 1.6s (ARG NEMOCLAW_PROXY_HOST=10.200.0.1)
  Step 60/80 : ARG NEMOCLAW_PROXY_PORT=3128
  Step 60/80 completed in 1.7s (ARG NEMOCLAW_PROXY_PORT=3128)
  Step 61/80 : ARG NEMOCLAW_WEB_SEARCH_ENABLED=0
  Step 61/80 completed in 1.6s (ARG NEMOCLAW_WEB_SEARCH_ENABLED=0)
  Step 62/80 : ENV NEMOCLAW_MODEL=${NEMOCLAW_MODEL}     NEMOCLAW_PROVIDER_KEY=${NEMOCLAW_PROVIDER_KEY}     NEMOCLAW_PRIMARY_MODEL_REF=${NEMOCLAW_PRI...
  Step 62/80 completed in 1.6s (ENV NEMOCLAW_MODEL=${NEMOCLAW_MODEL} NEMOCLAW_PROVIDER_KEY=${NEMOCLAW_PROVIDER_KEY} NEMOCLAW_PRIMARY_MODEL_REF=${NEM...
  Step 63/80 : WORKDIR /sandbox
  Step 63/80 completed in 1.7s (WORKDIR /sandbox)
  Step 64/80 : USER sandbox
  Step 64/80 completed in 1.7s (USER sandbox)
  Step 65/80 : RUN NEMOCLAW_OPENCLAW_MANAGED_PROXY=0 python3 /usr/local/lib/nemoclaw/generate-openclaw-config.py
  Step 65/80 completed in 2.4s (RUN NEMOCLAW_OPENCLAW_MANAGED_PROXY=0 python3 /usr/local/lib/nemoclaw/generate-openclaw-config.py)
  Step 66/80 : RUN python3 /usr/local/lib/nemoclaw/openclaw-build-messaging-plugins.py
  Step 66/80 completed in 16.9s (RUN python3 /usr/local/lib/nemoclaw/openclaw-build-messaging-plugins.py)
  Step 67/80 : ENV NPM_CONFIG_OFFLINE=true     NPM_CONFIG_AUDIT=false     NPM_CONFIG_FUND=false
  Step 67/80 completed in 1.8s (ENV NPM_CONFIG_OFFLINE=true NPM_CONFIG_AUDIT=false NPM_CONFIG_FUND=false)
  Step 68/80 : RUN openclaw plugins install /opt/nemoclaw     && openclaw plugins enable nemoclaw     && openclaw plugins inspect nemoclaw --json > ...
  Step 68/80 completed in 7.6s (RUN openclaw plugins install /opt/nemoclaw && openclaw plugins enable nemoclaw && openclaw plugins inspect nemoclaw ...
  Step 69/80 : RUN python3 -c "import json, os; path = os.path.expanduser('~/.openclaw/openclaw.json'); cfg = json.load(open(path)); cfg.setdefault(...
  Step 69/80 completed in 2.7s (RUN python3 -c "import json, os; path = os.path.expanduser('~/.openclaw/openclaw.json'); cfg = json.load(open(path))...
  Step 70/80 : USER root
  Step 70/80 completed in 1.9s (USER root)
  Step 71/80 : RUN set -eu;     config_dir=/sandbox/.openclaw;     data_dir=/sandbox/.openclaw-data;     legacy_layout=0;     legacy_marker=/tmp/nem...
  Step 71/80 completed in 2.7s (RUN set -eu; config_dir=/sandbox/.openclaw; data_dir=/sandbox/.openclaw-data; legacy_layout=0; legacy_marker=/tmp/ne...
  Step 72/80 : RUN if id gateway >/dev/null 2>&1 && id sandbox >/dev/null 2>&1; then         if ! id -nG gateway | tr ' ' '\n' | grep -qx sandbox; t...
  Step 72/80 completed in 2.5s (RUN if id gateway >/dev/null 2>&1 && id sandbox >/dev/null 2>&1; then if ! id -nG gateway | tr ' ' '\n' | grep -qx s...
  Step 73/80 : RUN set -eu;     if [ -e /tmp/nemoclaw-legacy-openclaw-layout ]; then         chown -R sandbox:sandbox /sandbox/.openclaw;         ch...
  Step 73/80 completed in 2.6s (RUN set -eu; if [ -e /tmp/nemoclaw-legacy-openclaw-layout ]; then chown -R sandbox:sandbox /sandbox/.openclaw; chmod...
  Step 74/80 : RUN if ! grep -q "/tmp/nemoclaw-proxy-env.sh" /etc/profile.d/nemoclaw-proxy.sh 2>/dev/null; then         printf '%s\n'             '#...
  Step 74/80 completed in 2.5s (RUN if ! grep -q "/tmp/nemoclaw-proxy-env.sh" /etc/profile.d/nemoclaw-proxy.sh 2>/dev/null; then printf '%s\n' '# Ne...
  Step 75/80 : RUN sha256sum /sandbox/.openclaw/openclaw.json > /sandbox/.openclaw/.config-hash     && chmod 660 /sandbox/.openclaw/.config-hash    ...
  Step 75/80 completed in 2.5s (RUN sha256sum /sandbox/.openclaw/openclaw.json > /sandbox/.openclaw/.config-hash && chmod 660 /sandbox/.openclaw/.co...
  Step 76/80 : RUN chown root:root /sandbox/.nemoclaw     && chmod 1755 /sandbox/.nemoclaw     && chown -R root:root /sandbox/.nemoclaw/blueprints  ...
  Step 76/80 completed in 2.5s (RUN chown root:root /sandbox/.nemoclaw && chmod 1755 /sandbox/.nemoclaw && chown -R root:root /sandbox/.nemoclaw/blu...
  Step 77/80 : RUN if [ "$NEMOCLAW_DARWIN_VM_COMPAT" = "1" ]; then         chmod -R a+rwX /sandbox/.openclaw;         find /sandbox/.openclaw -type ...
  Step 77/80 completed in 2.6s (RUN if [ "$NEMOCLAW_DARWIN_VM_COMPAT" = "1" ]; then chmod -R a+rwX /sandbox/.openclaw; find /sandbox/.openclaw -type...
  Step 78/80 : HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3     CMD port="${NEMOCLAW_DASHBOARD_PORT:-${OPENCLAW_GATEWAY_PO...
  Step 78/80 completed in 1.7s (HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 CMD port="${NEMOCLAW_DASHBOARD_PORT:-${OPENCL...
  Step 79/80 : ENTRYPOINT ["/usr/local/bin/nemoclaw-start"]
  Step 79/80 completed in 1.7s (ENTRYPOINT ["/usr/local/bin/nemoclaw-start"])
  Step 80/80 : CMD ["/bin/bash"]
  Step 80/80 completed in 1.8s (CMD ["/bin/bash"])
  Sandbox image build completed in 70.3s
  Creating sandbox in gateway...
  Built image openshell/sandbox-from:1780841875
  Waiting for sandbox to become ready...
  Sandbox reported Ready before create stream exited; continuing.
  Waiting for sandbox to become ready...
  Waiting for NemoClaw dashboard to become ready...
  ✓ Dashboard is live
  Restoring workspace state from pre-recreate backup...
  ✓ State restored (13 directories, 0 files)
  ✓ Sandbox 'spark-remote' created

  [7/8] Setting up OpenClaw inside sandbox
  ──────────────────────────────────────────────────
  ✓ OpenClaw gateway launched inside sandbox
  Verifying compatible endpoint through the messaging sandbox...
  ⚠ Gateway provider 'compatible-endpoint' did not report the selected endpoint URL.
    Continuing to the sandbox-side inference.local smoke check.
  ✓ Compatible endpoint responds through inference.local inside the sandbox

  [8/8] Policy presets
  ──────────────────────────────────────────────────

  Policy tier — controls which network presets are enabled:
     [ ] Restricted
   > [✓] Balanced
     [ ] Open

  ↑/↓ j/k  move    Space  select    Enter  confirm


  Presets  (Balanced defaults):
   > [✓] [rw] npm
     [✓] [rw] pypi
     [✓] [rw] huggingface
     [✓] [rw] brew
     [✓] [rw] brave
     [ ]      discord
     [ ]      github
     [ ]      jira
     [ ]      local-inference
     [ ]      nous-audio
     [ ]      nous-browser
     [ ]      nous-code
     [ ]      nous-image
     [ ]      nous-web
     [✓] [rw] openclaw-pricing
     [ ]      outlook
     [✓] [rw] slack
     [ ]      telegram
     [ ]      wechat
     [ ]      whatsapp

  ↑/↓ j/k  move    Space  include    r  toggle rw    Enter  confirm

  Widening sandbox egress — adding: registry.npmjs.org, registry.yarnpkg.com
✓ Policy version 3 submitted (hash: 9d0bc01ade48)
✓ Policy version 3 loaded (active version: 3)
  Applied preset: npm
  Widening sandbox egress — adding: pypi.org, files.pythonhosted.org
✓ Policy version 4 submitted (hash: 627a71354295)
✓ Policy version 4 loaded (active version: 4)
  Applied preset: pypi
  Widening sandbox egress — adding: huggingface.co, cdn-lfs.huggingface.co, router.huggingface.co
✓ Policy version 5 submitted (hash: c88edc8c67ce)
✓ Policy version 5 loaded (active version: 5)
  Applied preset: huggingface
  Widening sandbox egress — adding: formulae.brew.sh, github.com, ghcr.io, pkg-containers.githubusercontent.com, objects.githubusercontent.com, raw.githubusercontent.com
✓ Policy version 6 submitted (hash: 7f5062e2a5e9)
✓ Policy version 6 loaded (active version: 6)
  Applied preset: brew
  Widening sandbox egress — adding: api.search.brave.com
✓ Policy version 7 submitted (hash: 6292564060e6)
✓ Policy version 7 loaded (active version: 7)
  Applied preset: brave
  Widening sandbox egress — adding: raw.githubusercontent.com, openrouter.ai
✓ Policy version 8 submitted (hash: 9c0944278ab6)
✓ Policy version 8 loaded (active version: 8)
  Applied preset: openclaw-pricing
  ✓ Deployment verified — gateway and dashboard are healthy.
    OpenClaw version: 2026.5.22

  ──────────────────────────────────────────────────
  OpenClaw is ready

  Sandbox:  spark-remote
  Model:    nemotron-3-super:120b (Other OpenAI-compatible endpoint)

  Start chatting

    Browser:
      http://127.0.0.1:18789/

    Terminal:
      nemoclaw spark-remote connect
      then run: openclaw tui

  Authenticated dashboard URL, if needed:
    nemoclaw spark-remote dashboard-url --quiet

  Manage later

    Status:      nemoclaw spark-remote status
    Logs:        nemoclaw spark-remote logs --follow
    Model:       nemoclaw inference set --model <model> --provider <provider> --sandbox spark-remote
    Policies:    nemoclaw spark-remote policy-add
    Credentials: nemoclaw credentials reset <KEY> && nemoclaw onboard
  ──────────────────────────────────────────────────

jradtke@wheatley:~> sudo firewall-cmd --permanent --add-port=18789/tcp
jradtke@wheatley:~> sudo firewall-cmd --reload

jradtke@wheatley:~> openshell forward stop 18789 spark-remote
✓ Stopped forward of port 18789 for sandbox spark-remote
jradtke@wheatley:~> openshell forward start --background 0.0.0.0:18789 spark-remote
✓ Forwarding port 18789 to sandbox spark-remote in the background
  Access at: http://localhost:18789/
  Stop with: openshell forward stop 18789 spark-remote

openclaw gateway run
openclaw dashboard
</pre>
