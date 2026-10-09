# Model selection: by memory tier

Concrete picks by memory budget. See [`model-selection.md`](model-selection.md) for the
reasoning behind these choices.

Sizes below are the GGUF quant's approximate on-disk footprint, not the usable-memory
budget itself — leave room for KV cache and context per the rule of thumb in
[`model-selection.md`](model-selection.md).

Every pick here is a model of non-Chinese origin: Google's Gemma 4 family across the
tiers, OpenAI's gpt-oss where it fits, and Mistral's Devstral as a dense alternative.
Every GGUF named is a [ggml-org](https://huggingface.co/ggml-org) conversion — llama.cpp's
own organization — unless noted, and the section IDs in the recipes are the router's
`<repo>:<quant>` names for them (see [`config-presets.md`](config-presets.md)). Each
conversion carries its model's own Jinja chat template, which `[*]`'s `jinja = true`
applies; none of these recipes overrides it.

## 8GB

Google's [`google/gemma-4-E4B-it`](https://huggingface.co/google/gemma-4-E4B-it) (dense,
effective 4B) at `Q4_0` (~4.3GB), via
[`ggml-org/gemma-4-E4B-it-GGUF`](https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF). This
is the tightest tier for an agentic loop — expect to feel context-constrained. Its
`mmproj` (~0.5GB at `Q8_0`) adds image and audio input; the router loads it alongside
unless the section sets `no-mmproj = true`. `gemma-4-E2B-it` at `Q8_0` (~4.6GB) is the
smaller alternative. The small-model end of any lineup iterates fastest; check Google's
Hugging Face org for a more current small release before assuming this is still the best
option.

## 12GB and 16GB

Google's [`google/gemma-4-12B-it`](https://huggingface.co/google/gemma-4-12B-it) (dense),
via [`ggml-org/gemma-4-12B-it-GGUF`](https://huggingface.co/ggml-org/gemma-4-12B-it-GGUF):
`Q4_0` (~6.7GB) for 12GB, `Q8_0` (~11.8GB) for the extra headroom at 16GB. Gemma 4
includes native function-calling support per its own model card; verify its tool calls
through llama.cpp's `--jinja` path directly, per [`model-selection.md`](model-selection.md),
before relying on it.

An MoE alternative worth comparing at 16GB: OpenAI's
[`openai/gpt-oss-20b`](https://huggingface.co/openai/gpt-oss-20b) (21B-total/3.6B-active),
via [`ggml-org/gpt-oss-20b-GGUF`](https://huggingface.co/ggml-org/gpt-oss-20b-GGUF) at
`MXFP4` (~11.3GB) — the format it was released in, so there's no lower quant to step down
to. It leaves little room for context at 16GB; test it before trusting it over Gemma 4.

## 24GB

Google's [`google/gemma-4-26B-A4B-it`](https://huggingface.co/google/gemma-4-26B-A4B-it)
(MoE, 26B-total/4B-active), via
[`ggml-org/gemma-4-26B-A4B-it-GGUF`](https://huggingface.co/ggml-org/gemma-4-26B-A4B-it-GGUF)
at `Q4_0` (~13.6GB, plus ~0.8GB for its `Q8_0` vision `mmproj`) — the MoE pick, fast for
its quality, with room left for real context. Only 5 of its 30 layers hold a
full-attention KV cache (the rest are 1024-token sliding windows), so context is cheap;
the ~90-96GB entry below works through its numbers.

```ini
[ggml-org/gemma-4-26B-A4B-it-GGUF:Q4_0]
c = 65536
```

The dense alternative is
[`mistralai/Devstral-Small-2-24B-Instruct-2512`](https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512)
(GGUF via [bartowski](https://huggingface.co/bartowski/mistralai_Devstral-Small-2-24B-Instruct-2512-GGUF)
or [unsloth](https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF); no
ggml-org conversion), Mistral's own purpose-built agentic coding model — "excelling at
using tools to explore codebases, edit multiple files, and power SWE agents" by their own
description, fitting in roughly 25GB at Mistral's stated default quant.

Google's larger Gemma 4 dense variant,
[`google/gemma-4-31B-it`](https://huggingface.co/google/gemma-4-31B-it) (GGUF:
[`ggml-org/gemma-4-31B-it-GGUF`](https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF),
`Q4_0` ≈ 16.8GB), fits here too, with the 12GB/16GB entry's tool-calling caveat. Being
dense, it runs well below the 26B-A4B's speed on the same hardware.

## 48GB

Gemma 4 26B-A4B again, at `Q8_0` (~25.0GB) — a higher quant with real context headroom,
rather than the 24GB tier's `Q4_0` near the edge. `gemma-4-31B-it` at `Q8_0` (~30.4GB) is
the alternative if a dense model is preferred.

```ini
[ggml-org/gemma-4-26B-A4B-it-GGUF:Q8_0]
c = 65536
```

## ~90-96GB (unified memory)

Covered in detail in [`../preparation/framework-desktop.md`](../preparation/framework-desktop.md),
the concrete example running in this repo: **set A**, four models loaded side by side
in [`../profiles/unified-96gb.ini`](../profiles/unified-96gb.ini), each on 4 slots sharing
one KV pool (`parallel = 4`, `kv-unified = true` in `[*]`):

| Model | Role | Quant (~size) | `c` | KV bytes/token | KV at `c` |
|---|---|---|---|---|---|
| gpt-oss-120b | harness (`pi`), tool calls | `MXFP4` (~59GiB) | 131072 | 36,864 | 4.5GiB |
| Gemma 4 26B-A4B | vision | `Q4_0` + `Q8_0` mmproj (~14.4GiB) | 65536 | 20,480 | 1.25GiB |
| gemma-4-E4B | audio | `Q8_0` + `Q8_0` mmproj (~8.0GiB) | 32768 | 16,384 | 0.5GiB |
| EmbeddingGemma 2 | text embeddings | `Q8_0` (~0.3GiB) | 8192 | — | small |

Each `c` comes from the method in [`context-sizing.md`](context-sizing.md), applied to
each model's GGUF metadata:

- **gpt-oss-120b** ([`ggml-org/gpt-oss-120b-GGUF`](https://huggingface.co/ggml-org/gpt-oss-120b-GGUF),
  OpenAI's MoE, 117B-total/5.1B-active): 36 layers, attention alternating between full and
  a 128-token sliding window, so 18 hold a growing KV cache; `head_count_kv = 8`,
  `key_length = value_length = 64`. Per token that's `(64+64) × 8 × 2 × 18 = 36,864
  bytes`. Its trained `context_length` is `131072`, and at that `c` its KV cache is only
  4.5GiB beside ~59GiB of weights — so the trained context binds, not memory, and `c` is
  set to it.
- **Gemma 4 26B-A4B**: 30 layers, 5 of them full-attention with `head_count_kv = 2` and
  `key_length = value_length = 512`: `(512+512) × 2 × 2 × 5 = 20,480 bytes/token`. Its
  trained context is `262144`; `c = 65536` is what the shared budget affords alongside
  gpt-oss-120b. If the measured margin falls short, this is the `c` that drops (to 32768)
  first.
- **gemma-4-E4B**: 42 layers, 7 of them full-attention, and the last 18 layers reuse
  earlier layers' KV (`shared_kv_layers = 18`) — so 4 full-attention layers hold their own
  cache, at `(512+512) × 2 × 2 = 4,096 bytes/token` each: 16,384 bytes/token. Trained
  context `131072`; `c = 32768` covers audio clips and short exchanges.
- **EmbeddingGemma 2** ([`ggml-org/embeddinggemma-2-GGUF`](https://huggingface.co/ggml-org/embeddinggemma-2-GGUF)):
  `c = 8192`, the context window its card states. Embeddings only, mean pooling, 768
  dimensions; the repository's `mmproj` (image and audio encoders) is kept out with
  `no-mmproj = true`, and `b`/`ub` match `c` so an input fits in one physical batch.

On unified memory, the estimate above isn't the binding test: with all four loaded and
four requests in flight on each, `outpost amd usage` has to show at least 3GiB of the
96GiB pool free (see [`model-selection.md`](model-selection.md)).

```ini
[ggml-org/gpt-oss-120b-GGUF:MXFP4]
c = 131072

[ggml-org/gemma-4-26B-A4B-it-GGUF:Q4_0]
c = 65536

[ggml-org/gemma-4-E4B-it-GGUF:Q8_0]
c = 32768

[ggml-org/embeddinggemma-2-GGUF:Q8_0]
embeddings = true
pooling = mean
no-mmproj = true
c = 8192
b = 8192
ub = 8192
```
