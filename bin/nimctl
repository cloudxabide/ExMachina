#!/bin/bash
set -euo pipefail
#
# https://catalog.ngc.nvidia.com/
# https://docs.nvidia.com/nim/large-language-models/2.0.4/about-nim-llm/release-notes.html
# https://build.nvidia.com/spark/nim-llm/instructions

# Available NIM models: display-name -> NGC container image path (insertion order preserved via MODEL_KEYS)
# export IMG_NAME="nvcr.io/nim/meta/llama-3.1-8b-instruct-dgx-spark:latest" ## Recommended by NVIDIA
# nvcr.io/nim/meta/llama-3.3-70b-instruct << Most Promising thus far
# meta/llama-3.1-8b-instruct-dgx-spark << no tool support, apparently
# openai/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-NVFP4
#
declare -A NIM_MODELS=(
  ["llama-3.1-8b-instruct"]="meta/llama-3.1-8b-instruct-dgx-spark:latest"
  ["llama-3.1-nemotron-70b"]="nvidia/llama-3.1-nemotron-70b-instruct:1.2"
  ["nemotron-nano-9b"]="nvidia/nvidia-nemotron-nano-9b-v2-dgx-spark:1.0.0-variant"
  ["nemotron-3-8b"]="nvidia/nemotron-3:8b-instruct"
)

declare -A MODELS_THAT_WONT_WORK=(
  ["llama-3.3-70b-instruct"]="meta/llama-3.3-70b-instruct"
  ["nemotron-4-340b (requires multi-GPU)"]="nvidia/nemotron-4-340b-instruct:1.1.2"
)

# Model name as NIM serves it (used in litellm config — may differ from the NGC image path)
declare -A NIM_SERVER_NAMES=(
  ["llama-3.3-70b-instruct"]="meta/llama-3.3-70b-instruct"
  ["llama-3.1-8b-instruct"]="meta/llama-3.1-8b-instruct"
  ["llama-3.1-nemotron-70b"]="nvidia/llama-3.1-nemotron-70b-instruct"
  ["nemotron-nano-9b"]="nvidia/nvidia-nemotron-nano-9b-v2"
  ["nemotron-3-8b"]="nvidia/nemotron-3-8b-instruct"
  ["nemotron-4-340b (requires multi-GPU)"]="nvidia/nemotron-4-340b-instruct"
)

# Explicit ordering so the menu is stable across runs
MODEL_KEYS=(
  "llama-3.1-8b-instruct"
  "llama-3.1-nemotron-70b"
  "nemotron-nano-9b"
  "nemotron-3-8b"
)

echo "Available NIM models:"
PS3="Select a model (enter number): "
select CHOICE in "${MODEL_KEYS[@]}" "Quit"; do
  if [[ "$CHOICE" == "Quit" ]]; then
    echo "Exiting."
    exit 0
  elif [[ -n "${NIM_MODELS[$CHOICE]+_}" ]]; then
    export NIM_MODEL_NAME="${NIM_MODELS[$CHOICE]}"
    export NIM_SERVER_MODEL="${NIM_SERVER_NAMES[$CHOICE]}"
    echo "Selected: $CHOICE -> $NIM_MODEL_NAME (serves as: $NIM_SERVER_MODEL)"
    break
  else
    echo "Invalid selection, try again."
  fi
done

# Short name used for container name and litellm model routing
export CONTAINER_NAME=$(basename "$NIM_MODEL_NAME" | cut -d: -f1)
LITELLM_CONTAINER_NAME="${CONTAINER_NAME}-litellm-proxy"

# Choose a NIM Image from NGC
export IMG_NAME="nvcr.io/nim/$NIM_MODEL_NAME"

export LOCAL_NIM_CACHE=~/.cache/nim
export LOCAL_NIM_WORKSPACE=~/.local/share/nim/workspace
mkdir -p "$LOCAL_NIM_WORKSPACE"
chmod -R u+rwx "$LOCAL_NIM_WORKSPACE"
mkdir -p "$LOCAL_NIM_CACHE"
chmod -R u+rwx "$LOCAL_NIM_CACHE"

# Validate NGC_API_KEY is set
if [[ -z "$NGC_API_KEY" ]]; then
  echo "ERROR: NGC_API_KEY is not set. Export it before running this script."
  exit 1
fi

# Log in to NGC container registry
echo "Logging in to nvcr.io..."
if ! echo "$NGC_API_KEY" | docker login nvcr.io --username '$oauthtoken' --password-stdin; then
  echo "ERROR: docker login to nvcr.io failed. Check your NGC_API_KEY."
  exit 1
fi

# Ask whether to start the litellm proxy (OpenAI + Anthropic compatible, port 4000)
START_PROXY=false
read -rp "Start litellm proxy for Claude Code / OpenCode access (port 4000)? [y/N]: " PROXY_CHOICE
if [[ "$PROXY_CHOICE" =~ ^[Yy]$ ]]; then
  START_PROXY=true
fi

inspect() {
  #for IMG in $(docker images | awk '{ print $1 }'); do docker inspect --format='{{.Architecture}}' $IMG; done
  for IMG in $(docker images | awk '{ print $1 }'); do docker inspect --format='{{.Os}}/{{.Architecture}}' $IMG; done
  for IMG in $(docker images --format "{{.Repository}}"); do docker inspect --format='{{.Os}}/{{.Architecture}}' $IMG; done
}

cleanup() {
  if [[ "$START_PROXY" == true ]]; then
    echo ""
    echo "Stopping litellm proxy container..."
    docker stop "$LITELLM_CONTAINER_NAME" 2>/dev/null
    [[ -n "${LITELLM_CONFIG_DIR:-}" ]] && rm -rf "$LITELLM_CONFIG_DIR"
  fi
}
trap cleanup EXIT

# Start litellm proxy before NIM so it's ready when NIM finishes loading
if [[ "$START_PROXY" == true ]]; then
  # Determine the primary interface IP
  PRIMARY_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7; exit}')
  [[ -z "$PRIMARY_IP" ]] && PRIMARY_IP="0.0.0.0"

  # Write a litellm config that maps any Claude model name -> NIM backend.
  # The wildcard model_name is required because Claude Code sends its own model name
  # (e.g. claude-sonnet-4-6) in requests; without this mapping litellm rejects the mismatch.
  LITELLM_CONFIG_DIR=$(mktemp -d)
  cat > "$LITELLM_CONFIG_DIR/config.yaml" <<EOF
model_list:
  - model_name: "*"
    litellm_params:
      model: "$NIM_SERVER_MODEL"
      api_base: "http://localhost:8000/v1"
      api_key: "dummy"
EOF

  if docker inspect "$LITELLM_CONTAINER_NAME" >/dev/null 2>&1; then
    OLD_NAME="${LITELLM_CONTAINER_NAME}-$(date +%Y%m%d-%H%M%S)"
    echo "Container '$LITELLM_CONTAINER_NAME' already exists — renaming to '$OLD_NAME' and stopping..."
    docker rename "$LITELLM_CONTAINER_NAME" "$OLD_NAME"
    docker stop "$OLD_NAME" 2>/dev/null || true
  fi

  echo "Starting litellm proxy on ${PRIMARY_IP}:4000 -> http://localhost:8000/v1 ..."
  docker run -d --rm \
    --name="$LITELLM_CONTAINER_NAME" \
    --network=host \
    -e OPENAI_API_KEY=dummy \
    -v "$LITELLM_CONFIG_DIR/config.yaml:/app/config.yaml:ro" \
    ghcr.io/berriai/litellm:main-latest \
    --config /app/config.yaml \
    --port 4000 \
    --host "$PRIMARY_IP"

  # Wait for litellm to become ready on port 4000
  echo "Waiting for litellm to start on port 4000..."
  LITELLM_READY=false
  for i in $(seq 1 30); do
    if curl -sf "http://${PRIMARY_IP}:4000/health" >/dev/null 2>&1; then
      LITELLM_READY=true
      break
    fi
    sleep 2
  done

  if [[ "$LITELLM_READY" == false ]]; then
    echo "ERROR: litellm did not start within 60 seconds on ${PRIMARY_IP}:4000. Check logs with:"
    echo "  docker logs $LITELLM_CONTAINER_NAME"
    docker stop "$LITELLM_CONTAINER_NAME" 2>/dev/null
    exit 1
  fi
  echo "litellm is ready."

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  litellm proxy started. Configure your tools:"
  echo ""
  echo "  OpenCode:"
  echo "    export OPENAI_BASE_URL=http://${PRIMARY_IP}:4000/v1"
  echo "    export OPENAI_API_KEY=dummy"
  echo ""
  echo "  Claude Code:"
  echo "    export ANTHROPIC_BASE_URL=http://${PRIMARY_IP}:4000"
  echo "    export ANTHROPIC_API_KEY=dummy"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# Start the NIM (foreground — proxy cleanup runs on exit via trap)
if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  OLD_NAME="${CONTAINER_NAME}-$(date +%Y%m%d-%H%M%S)"
  echo "Container '$CONTAINER_NAME' already exists — renaming to '$OLD_NAME' and stopping..."
  docker rename "$CONTAINER_NAME" "$OLD_NAME"
  docker stop "$OLD_NAME" 2>/dev/null || true
fi

echo "Running: docker run -it --rm --name=$CONTAINER_NAME --gpus all --shm-size=16GB -e NGC_API_KEY=<redacted> -v $LOCAL_NIM_CACHE:/opt/nim/.cache -v $LOCAL_NIM_WORKSPACE:/opt/nim/workspace -p 8000:8000 $IMG_NAME"
echo ""
docker run -it --rm --name="$CONTAINER_NAME" \
  --gpus all \
  --shm-size=16GB \
  -e NGC_API_KEY="$NGC_API_KEY" \
  -e NIM_SERVED_MODEL_ARGS="--enable-auto-tool-choice --tool-call-parser llama3_json" \
  -e NIM_SERVED_MODEL_ARGS="--max-model-len 4096 --gpu-memory-utilization 0.95" \
  -v "$LOCAL_NIM_CACHE:/opt/nim/.cache" \
  -v "$LOCAL_NIM_WORKSPACE:/opt/nim/workspace" \
  -p 8000:8000 \
  "$IMG_NAME"


exit 0

# References
# https://docs.nvidia.com/nim/large-language-models/latest/reference/support-matrix.html
