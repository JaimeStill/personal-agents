# Model selection: how to reason about it

A guide to picking a model for a given host's memory budget, for agentic tool-calling
through `pi` specifically — not general chat quality. A model that tops a chat leaderboard
but doesn't round-trip tool calls cleanly through llama.cpp's `--jinja` templating is worse
here than a smaller one that does.

This is a snapshot as of September 2026. Model rankings move fast; the reasoning below
should stay useful longer than any specific name does — recheck the current state of a
model family before committing disk space and time to it. For concrete picks by memory
budget, see [`model-tiers.md`](model-tiers.md).

**Usable memory, not raw memory.** Budget roughly 85-90% of a GPU's or host's total memory
for weights plus KV cache; the rest goes to the OS, drivers, and other overhead. A model
whose weights alone consume the full budget leaves no room for context.

That 85-90% is the planning estimate. On unified memory (a GTT pool, as on a Strix Halo
host), the binding test is measured: with every model in the profile loaded and four
requests in flight on each, `outpost amd usage` (see
[`memory-footprint.md`](memory-footprint.md)) shows at least 3GiB of the pool free. A
profile that passes the estimate but fails the measurement is over budget: shrink the `c`
its recipes name as the first to drop, and measure again.

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
