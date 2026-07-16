# TensorRT-LLM on spark-e — Notes

Guide: https://build.nvidia.com/spark/trt-llm/instructions

## What

Ran TensorRT-LLM's `trtllm-serve` on spark-e (10.10.12.251) alongside the
existing vLLM deployment, serving `nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16`
on port 8355.

## Launch command

```bash
export MODEL_HANDLE="nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16"

docker run --name trtllm_llm_server --rm -it --gpus all --ipc host --network host \
  -e HF_TOKEN=$HF_TOKEN \
  -e MODEL_HANDLE="$MODEL_HANDLE" \
  -v $HOME/.cache/huggingface/:/root/.cache/huggingface/ \
  $DOCKER_IMAGE \
  bash -c '
    hf download $MODEL_HANDLE && \
    cat > nano_v3.yaml <<EOF
kv_cache_config:
  enable_block_reuse: false
  free_gpu_memory_fraction: 0.80
  mamba_ssm_cache_dtype: float32
moe_config:
  backend: CUTLASS
cuda_graph_config:
  enable_padding: true
  max_batch_size: 1
max_batch_size: 1
EOF
    PYTORCH_ALLOC_CONF=expandable_segments:True \
    trtllm-serve serve "$MODEL_HANDLE" \
      --host 0.0.0.0 \
      --port 8355 \
      --trust_remote_code \
      --reasoning_parser nano-v3 \
      --tool_parser qwen3_coder \
      --extra_llm_api_options nano_v3.yaml
  '
```

Note: `max_batch_size: 1` in both the extra options file and the top-level
flag — this config serves one request at a time, not tuned for concurrency.

## Verification

Container status:

```bash
ssh -i ~/.ssh/id_ecdsa-kubernerdes jradtke@10.10.12.251 \
  "docker ps --filter name=trtllm_llm_server"
```

Health check:

```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://10.10.12.251:8355/health
# HTTP 200
```

Chat completion (confirms `nano-v3` reasoning parser splits `reasoning_content`
from `content` correctly):

```bash
curl -s http://10.10.12.251:8355/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16",
    "messages": [{"role": "user", "content": "In one sentence, what is the capital of France?"}],
    "max_tokens": 100,
    "temperature": 0
  }'
```

Tool calling (confirms `qwen3_coder` tool parser produces structured
`tool_calls`):

```bash
curl -s http://10.10.12.251:8355/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16",
    "messages": [{"role": "user", "content": "What is the weather in Paris right now? Use the get_weather tool."}],
    "tools": [{
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get current weather for a location",
        "parameters": {
          "type": "object",
          "properties": {"location": {"type": "string"}},
          "required": ["location"]
        }
      }
    }],
    "max_tokens": 200,
    "temperature": 0
  }'
```

Both requests returned in ~3-4s with correct output. First-token-to-response
latency and `reasoning_content`/`tool_calls` fields matched expectations for
an OpenAI-compatible endpoint.

## Open items

- Not yet compared against vLLM (throughput, latency, memory footprint) for
  the same model class on spark-e.
- `max_batch_size: 1` means this isn't representative of concurrent-load
  behavior — revisit before treating this as a production candidate.
