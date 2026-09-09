# Model selection

A guide to picking a model for a given host's memory budget, for agentic tool-calling
through `pi` specifically — not general chat quality. A model that tops a chat leaderboard
but doesn't round-trip tool calls cleanly through llama.cpp's `--jinja` templating is worse
here than a smaller one that does.

This is a snapshot as of September 2026. Model rankings move fast; the reasoning below
should stay useful longer than any specific name in the tables does — recheck the current
state of a model family before committing disk space and time to it.

This picks *which* model and *what configuration* it needs; see
[`config.md`](config.md) for how that configuration actually gets applied.

## How to reason about it

**Usable memory, not raw memory.** Budget roughly 85-90% of a GPU's or host's total memory
for weights plus KV cache; the rest goes to the OS, drivers, and other overhead. A model
whose weights alone consume the full budget leaves no room for context.

**Dense vs. mixture-of-experts (MoE) isn't a universal win for MoE.** MoE's efficiency
edge (a large total footprint, but only a few billion parameters active per token) is
scale-dependent, not automatic. At small total sizes a well-trained dense model can match
or beat a much larger MoE — QwQ-32B (dense) matches or beats DeepSeek-R1 (671B MoE) on
tool-use and agentic tasks specifically
([arXiv:2604.09175](https://arxiv.org/pdf/2604.09175)). MoE tends to start clearly paying
off from roughly the 24GB tier upward, where a model can activate ~3B params per token at
near-dense-27B quality. Below that, treat dense as the safer default and MoE as worth
comparing, not assuming.

**Quantization degrades tool-calling before it visibly degrades chat quality.** The
literature on this is thin and task-dependent rather than a single clean curve
([Fireworks](https://fireworks.ai/blog/fireworks-quantization)), but the practical,
repeatedly-observed signal is: start at `Q4_K_M`; if tool calls come back malformed or
drop parameters, move up a quant level on the *same* model before concluding the model
itself is wrong for the job.

**Verify `--jinja` tool-calling before committing to a model, every time.** Chat templates
break in ways that are easy to miss until a model tries to call a tool. A documented case:
Qwen's official Jinja templates have had bugs in llama.cpp serious enough to 500 the
request (a missing `reject` filter rendering tool blocks), with a community-maintained
[fixed-template repo](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates) as the
workaround and an unmerged
[`autoparser` branch](https://github.com/pwilkin/llama.cpp/tree/autoparser) reported to
fix tool-calling more broadly (see also llama.cpp's own
[function-calling docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md)
and [issue #19872](https://github.com/ggml-org/llama.cpp/issues/19872)). This isn't unique
to Qwen; check for it on any model before relying on it.

## By memory tier

Sizes below are the GGUF quant's approximate on-disk footprint, not the usable-memory
budget itself — leave room for KV cache and context per the rule of thumb above.

### 8GB

[`Qwen/Qwen3-8B`](https://huggingface.co/Qwen/Qwen3-8B) (dense) at `Q4_K_M` (~5GB) is a
known, working quantity at this size. This is the tightest tier for an agentic loop —
expect to feel context-constrained. The small-model end of any lineup iterates fastest;
check the Qwen (and Ornith, below) Hugging Face orgs for a more current small release
before assuming this is still the best option.

### 12GB and 16GB

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
[`config.md`](config.md)):

```ini
[unsloth/gemma-4-12b-it-GGUF:Q4_K_M]
chat-template = gemma
```

An MoE alternative worth comparing at 16GB:
[`bartowski/Ornith-1.5-35B-A3B-GGUF`](https://huggingface.co/bartowski/Ornith-1.5-35B-A3B-GGUF)
at an aggressive quant (`IQ3_XXS`/`IQ2_S`, roughly 13-14GB) — see the 24GB entry below for
what it is; aggressive quantization is exactly where the tool-calling-degrades-first
caveat above matters most, so test it before trusting it over Gemma 4.

### 24GB

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

### 48GB

[`unsloth/Qwen3.6-35B-A3B-GGUF`](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF)
(MoE, 35B-total/3B-active) at `Q6_K` or `Q8_0` — roughly 20GB at `Q4_K_M`, so a higher
quant fits comfortably here with real context headroom, rather than running the same
model right at the edge the way the 24GB tier does. `Qwen3.6-27B` (dense) is the
alternative if a dense model is preferred, at a similarly generous quant.

### ~90-96GB (unified memory)

Covered in detail in [`../preparation/framework-desktop.md`](../preparation/framework-desktop.md),
the concrete example already running in this repo: `unsloth/Qwen3-Coder-Next-GGUF:Q5_K_M`
(MoE, 80B-total/3B-active, ~53GB), with `gpt-oss-120b` (MXFP4, ~59GB) as the fallback if
the chat template misbehaves.
