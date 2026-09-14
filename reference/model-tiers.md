# Model selection: by memory tier

Concrete picks by memory budget. See [`model-selection.md`](model-selection.md) for the
reasoning behind these choices.

Sizes below are the GGUF quant's approximate on-disk footprint, not the usable-memory
budget itself — leave room for KV cache and context per the rule of thumb in
[`model-selection.md`](model-selection.md).

## 8GB

[`Qwen/Qwen3-8B`](https://huggingface.co/Qwen/Qwen3-8B) (dense) at `Q4_K_M` (~5GB) is a
known, working quantity at this size. This is the tightest tier for an agentic loop —
expect to feel context-constrained. The small-model end of any lineup iterates fastest;
check the Qwen (and Ornith, below) Hugging Face orgs for a more current small release
before assuming this is still the best option.

## 12GB and 16GB

Google's [`google/gemma-4-12B-it`](https://huggingface.co/google/gemma-4-12B-it) (dense,
April 2026), via the GGUF conversion
[`unsloth/gemma-4-12b-it-GGUF`](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF) —
Google doesn't publish GGUF directly, so a community conversion is the actual usable
artifact for llama.cpp. `Q4_K_M` for 12GB, `Q6_K`/`Q8_0` for the extra headroom at 16GB.
Gemma 4 includes native function-calling support per its own model card, but its
tool-calling track record specifically through llama.cpp's `--jinja` path is less
established than Qwen's in what this research turned up — verify it directly rather than
assuming parity. It also requires `--chat-template gemma` explicitly; without it, output is
garbled, since its BOS/EOS tokens differ from Llama's defaults.

Recipe (any Gemma 4 quant, in a `[*]`-uses-`--jinja` router — see
[`config-convention.md`](config-convention.md)):

```ini
[unsloth/gemma-4-12b-it-GGUF:Q4_K_M]
chat-template = gemma
```

An MoE alternative worth comparing at 16GB:
[`bartowski/Ornith-1.5-35B-A3B-GGUF`](https://huggingface.co/bartowski/Ornith-1.5-35B-A3B-GGUF)
at an aggressive quant (`IQ3_XXS`/`IQ2_S`, roughly 13-14GB) — see the 24GB entry below for
what it is; aggressive quantization is exactly where the tool-calling-degrades-first
caveat above matters most, so test it before trusting it over Gemma 4.

## 24GB

[`bartowski/Ornith-1.5-35B-A3B-GGUF`](https://huggingface.co/bartowski/Ornith-1.5-35B-A3B-GGUF)
at `Q4_K_M` (~22GB) is the pick built specifically for this evaluation lens: a
35B-total/3B-active MoE trained via self-improving reinforcement learning specifically on
agentic coding benchmarks (Terminal-Bench, SWE-Bench,
[Ornith's own writeup](https://ornith.ai/ornith_1_0.html)).

The dense alternative is
[`mistralai/Devstral-Small-2-24B-Instruct-2512`](https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512)
(GGUF via [bartowski](https://huggingface.co/bartowski/mistralai_Devstral-Small-2-24B-Instruct-2512-GGUF)
or [unsloth](https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF)),
Mistral's own purpose-built agentic coding model — "excelling at using tools to explore
codebases, edit multiple files, and power SWE agents" by their own description, fitting in
roughly 25GB at Mistral's stated default quant.

[`Qwen/Qwen3.8-27B`](https://huggingface.co/Qwen/Qwen3.8-27B) is the newest Qwen dense
release at this size and worth evaluating, but it's recent enough that this research
couldn't confirm its `--jinja` tool-calling track record specifically — check it against
the standing caveat above before relying on it over the two options above.

Google's larger Gemma 4 dense variant,
[`google/gemma-4-31B-it`](https://huggingface.co/google/gemma-4-31B-it) (GGUF:
[`unsloth/gemma-4-31B-it-GGUF`](https://huggingface.co/unsloth/gemma-4-31B-it-GGUF),
`Q4_K_M` ≈ 18.3GB), fits here too — same recipe and caveats as the 12GB/16GB entry above
(`chat-template = gemma` required, tool-calling track record unconfirmed relative to
Qwen's).

## 48GB

[`unsloth/Qwen3.6-35B-A3B-GGUF`](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF)
(MoE, 35B-total/3B-active) at `Q6_K` or `Q8_0` — roughly 20GB at `Q4_K_M`, so a higher
quant fits comfortably here with real context headroom, rather than running the same
model right at the edge the way the 24GB tier does. `Qwen3.6-27B` (dense) is the
alternative if a dense model is preferred, at a similarly generous quant.

## ~90-96GB (unified memory)

Covered in detail in [`../preparation/framework-desktop.md`](../preparation/framework-desktop.md),
the concrete example already running in this repo: `unsloth/Qwen3-Coder-Next-GGUF:Q5_K_M`
(MoE, 80B-total/3B-active, ~53GB), with `gpt-oss-120b` (MXFP4, ~59GB) as the fallback if
the chat template misbehaves.

Qwen3-Coder-Next gets a larger `c` than `[*]`'s default (`32768`, sized for gpt-oss-120b),
by the method in [`context-sizing.md`](context-sizing.md#sizing-a-models-c). Its GGUF
metadata (`qwen3next.*`) gives 48 layers with `full_attention_interval = 4` (12 real-KV-cache
layers; the other 36 are Gated DeltaNet layers with a fixed-size state), `head_count_kv
= 2`, `key_length = value_length = 256`, and a trained `context_length` of `262144`. Per
token that's `(256+256) × 2 × 2 × 12 = 24,576 bytes` — versus gpt-oss-120b's confirmed
`(64+64) × 8 × 2 × 18 = 36,864 bytes/token` (identical 2048 bytes/token/layer; the
difference is entirely the full-attention-layer fraction, 25% vs. 50%). At any plausible
`c` this cost is trivial next to the ~53GB weight footprint (0.75GiB at `c = 32768`,
3.0GiB at `c = 131072`, even before assuming `--kv-unified` sharing), so the trained
context is what actually binds, not memory. `c = 131072` — half the trained maximum,
leaving margin below the RoPE-trained ceiling — is the recipe:

```ini
[unsloth/Qwen3-Coder-Next-GGUF:Q5_K_M]
c = 131072
```
