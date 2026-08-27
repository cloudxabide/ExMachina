# Opencode with DGX Spark

There are seemingly no end to the ways one may run an LLM and connect opencode

I have landed here - and it seems to work rather well

```
    "DGX-VLLM": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "NVIDIA DGX Spark - vLLM",
      "options": {
        "baseURL": "http://10.10.12.251:8000/v1",
        "apiKey": "dummy-key"
      },
      "models": {
        "nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4": {
          "name": "Nemotron Super 120B"
        },
        "nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-NVFP4": {
          "name": "Nemotron Nano 30B"
        },
        "unsloth/Llama-3.3-70B-Instruct-FP8-Dynamic": {
          "name": "Llama 3.3 70B Instruct"
        },
        "meta/llama-3.1-8b-instruct": {
          "tool_call": false
        },
        "nvidia/Qwen3.6-35B-A3B-NVFP4": {
          "name": "Qwen3.6 35B A3B",
          "tool_call": true
        }
      }
    },

```

```
  docker run --gpus all --ipc=host -d --name qwen36-35b-a3b \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    -e HF_TOKEN="$HF_TOKEN" \
    -e CUTE_DSL_ARCH=sm_121a \
    -e FLASHINFER_DISABLE_VERSION_CHECK=1 \
    -p 8000:8000 \
    vllm/vllm-openai:latest \
    --model nvidia/Qwen3.6-35B-A3B-NVFP4 \
    --host 0.0.0.0 --port 8000 \
    --tensor-parallel-size 1 --trust-remote-code \
    --quantization modelopt \
    --kv-cache-dtype fp8 --attention-backend flashinfer \
    --moe-backend marlin --gpu-memory-utilization 0.6 \
    --max-model-len 262144 --enable-prefix-caching \
    --reasoning-parser qwen3 \
    --enable-auto-tool-choice \
    --tool-call-parser qwen3_coder
```

  Environment: DGX Spark, GB10 GPU (Blackwell, SM 12.1), CUDA 13.0, driver 580.173.02

  Docker image: vllm/vllm-openai:latest (was v0.28.0 as of this session)

  Why these specific flags (worth keeping in the doc so a future rebuild doesn't have to rediscover it):
  - --moe-backend marlin — the only NVFP4 MoE kernel that actually works on GB10; flashinfer_cutlass targets datacenter Blackwell (SM 10.0) and rejects this
  checkpoint's quant layout on GB10, triton isn't a valid NVFP4 MoE backend at all
  - CUTE_DSL_ARCH=sm_121a / FLASHINFER_DISABLE_VERSION_CHECK=1 — required for GB10's SM 12.1 to be recognized correctly by the FlashInfer/CUTLASS DSL layer
  - vllm/vllm-openai:latest (not cu130-nightly) — the nightly's older vLLM (v0.19.2) has a Qwen3.5-MoE weight loader that doesn't match this checkpoint's expert
  key names (KeyError: w2_input_scale)
  - --tool-call-parser qwen3_coder — this model emits <function=name><parameter=x>... XML-style tool calls; hermes (JSON-style) and qwen3_xml don't parse it into
  tool_calls correctly, only qwen3_coder does
  - --reasoning-parser qwen3 — this is a thinking model; without it the <think> trace isn't separated from content/reasoning, and callers should budget
  max_tokens generously (≥500-1000) since the reasoning trace itself consumes tokens before any answer or tool call is emitted

  Serving endpoint: http://localhost:8000/v1 (OpenAI-compatible: chat completions, tool calling via tools/tool_choice, up to 262K context)


## THIS WAS CLOSE, but did not work
  Final working command (container name qwen36-35b-a3b):
```
  docker run --gpus all --ipc=host -d --name qwen36-35b-a3b \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    -e HF_TOKEN="$HF_TOKEN" \
    -e CUTE_DSL_ARCH=sm_121a \
    -e FLASHINFER_DISABLE_VERSION_CHECK=1 \
    -p 8000:8000 \
    vllm/vllm-openai:latest \
    --model nvidia/Qwen3.6-35B-A3B-NVFP4 \
    --host 0.0.0.0 --port 8000 \
    --tensor-parallel-size 1 --trust-remote-code \
    --quantization modelopt \
    --kv-cache-dtype fp8 --attention-backend flashinfer \
    --moe-backend marlin --gpu-memory-utilization 0.6 \
    --max-model-len 262144 --enable-prefix-caching \
    --reasoning-parser qwen3 \
    --enable-auto-tool-choice \
    --tool-call-parser qwen3_coder
  
#  --tool-call-parser hermes
```


● It ran cleanly: 0 failed requests, ~184 tok/s output throughput at concurrency 4, ~19.8ms/token (≈50 tok/s per stream), TTFT ~350ms median.

  Results at concurrency 4

  ┌───────────────────────────┬──────────────────────────────┐
  │          Metric           │            Value             │
  ├───────────────────────────┼──────────────────────────────┤
  │ Output throughput         │ 183.7 tok/s                  │
  ├───────────────────────────┼──────────────────────────────┤
  │ Total throughput (in+out) │ 558.6 tok/s                  │
  ├───────────────────────────┼──────────────────────────────┤
  │ Mean TTFT                 │ 353 ms                       │
  ├───────────────────────────┼──────────────────────────────┤
  │ Mean TPOT (per-token)     │ 19.8 ms (~50.5 tok/s/stream) │
  └───────────────────────────┴──────────────────────────────┘

  That per-stream ~50 tok/s roughly matches the "20-30 tok/s" the HF discussion mentioned for a less-tuned config, so marlin MoE + fp8 KV cache is
  doing well here.

  Suggestions for going further

  1. Sweep concurrency to find where throughput saturates and TTFT starts degrading — run the same command at --max-concurrency 1, 2, 8, 16, 32 and
  compare. That tells you the practical max concurrent users before latency suffers.
  2. Match your real workload shape — swap --random-input-len/--random-output-len for numbers closer to what you'll actually send (e.g. short chat
  turns vs. long-context RAG).
  3. Realistic conversational traffic: use --dataset-name sharegpt instead of random for more natural prompt/response distributions.
  4. Since you have a 262K context window, worth a long-context test: --random-input-len 32000 --random-output-len 512 to see how TTFT scales with
  prefill length.
  5. Add --save-detailed if you want per-request timing dumped to the JSON for deeper analysis (e.g. plotting TTFT distribution).


 Here's the command you can run yourself anytime — no need for me to be involved:

  docker exec qwen36-35b-a3b vllm bench serve \
    --backend openai-chat \
    --endpoint /v1/chat/completions \
    --model nvidia/Qwen3.6-35B-A3B-NVFP4 \
    --host localhost --port 8000 \
    --dataset-name random \
    --random-input-len 512 \
    --random-output-len 256 \
    --num-prompts 50 \
    --max-concurrency 4 \
    --save-result --result-dir /tmp --result-filename bench_c4.json

  Notes on the knobs you'll want to change:
  - --max-concurrency N — simulate N simultaneous users (the main thing to vary)
  - --num-prompts — total requests sent; keep it a multiple of concurrency, roughly 10x concurrency so the run is long enough to be stable
  - --random-input-len / --random-output-len — shape of prompt/response to match your real use case
  - --result-filename — change per run so you can diff results later; files land in /tmp inside the container (add -v mount if you want them on host)

  Now running the concurrency sweep (1, 2, 4, 8, 16, 32) in the background — I'll summarize the throughput/latency curve when it's done.

   for c in 1 2 4 8 16 32; do
     echo "=== concurrency $c ==="
     n=$((c * 10))
     docker exec qwen36-35b-a3b vllm bench serve \
       --backend openai-chat \
       --endpoint /v1/chat/completions \
       --model nvidia/Qwen3.6-35B-A3B-NVFP4 \
       --host localhost --port 8000 \
       --dataset-name random \
       --random-input-len 512 \
       --random-output-len 256 \
       --num-prompts "$n" \
       --max-concurrency "$c" \
       --save-result --result-dir /tmp --result-filename "bench_c${c}.json" 2>&1 | grep -A30 "Serving Benchmark Result"
   done

● All 620 requests across the sweep succeeded, 0 failures. Here's the full curve:

  ┌─────────────┬──────────────┬─────────────┬───────────┬───────────┬──────────────────┬──────────┐
  │ Concurrency │ Output tok/s │ Total tok/s │ Mean TTFT │ Mean TPOT │ Per-stream tok/s │ P99 ITL  │
  ├─────────────┼──────────────┼─────────────┼───────────┼───────────┼──────────────────┼──────────┤
  │ 1           │ 76.1         │ 231.2       │ 133 ms    │ 12.7 ms   │ 78.9             │ 15.5 ms  │
  ├─────────────┼──────────────┼─────────────┼───────────┼───────────┼──────────────────┼──────────┤
  │ 2           │ 116.3        │ 353.7       │ 203 ms    │ 16.5 ms   │ 60.8             │ 19.8 ms  │
  ├─────────────┼──────────────┼─────────────┼───────────┼───────────┼──────────────────┼──────────┤
  │ 4           │ 189.0        │ 574.7       │ 329 ms    │ 20.0 ms   │ 50.1             │ 23.7 ms  │
  ├─────────────┼──────────────┼─────────────┼───────────┼───────────┼──────────────────┼──────────┤
  │ 8           │ 267.0        │ 811.8       │ 531 ms    │ 28.0 ms   │ 35.7             │ 33.1 ms  │
  ├─────────────┼──────────────┼─────────────┼───────────┼───────────┼──────────────────┼──────────┤
  │ 16          │ 367.6        │ 1117.6      │ 724 ms    │ 40.8 ms   │ 24.5             │ 152.1 ms │
  ├─────────────┼──────────────┼─────────────┼───────────┼───────────┼──────────────────┼──────────┤
  │ 32          │ 475.6        │ 1446.3      │ 929 ms    │ 63.8 ms   │ 15.7             │ 287.6 ms │
  └─────────────┴──────────────┴─────────────┴───────────┴───────────┴──────────────────┴──────────┘

  What this tells you:
  - Aggregate throughput keeps climbing through 32 (never fully plateaus), but with clear diminishing returns — each doubling of concurrency buys progressively
  less: 1→2 is +53%, but 16→32 is only +29%.
  - Per-request latency degrades roughly linearly with load: single-stream generation goes from 79 tok/s down to 16 tok/s at concurrency 32, because it's one
  GB10 GPU doing all the compute — there's no cross-GPU parallelism to hide the batching cost.
  - Tail latency (P99 ITL) is where it really breaks down: it stays close to the mean through concurrency 8, then jumps sharply at 16 and 32 (152ms and 288ms vs.
  ~40-64ms mean) — a sign the scheduler is queuing under load and some requests are getting starved.

  Practical takeaway: for interactive/chat use, concurrency 4-8 is the sweet spot — sub-second TTFT, tail latency still well-behaved, and you're already
  capturing most of the achievable throughput. Push past 16 only if you're optimizing for batch/offline throughput and don't care about individual response
  latency.

