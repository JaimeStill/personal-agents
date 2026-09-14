# reset · personal-agents

- **Status:** closeout
- **Session:** start
- **Branch:** tuning.qwen-context-budget

## Disposition
- **Integrated:** `research/framework-desktop-followups.md`'s "Model architecture changes
  the real cost of context" section — corrected the "narrower KV-head count... different
  order of scaling" claim against exact GGUF metadata (both models cost 2048
  bytes/token/layer; the saving is the full-attention-layer fraction, 12/48 vs 18/36,
  ~1.5x not an order of magnitude) and recorded the live confirmation (`c = 131072`,
  ~56.6GiB loaded vs. ~53GiB weight footprint). Dropped "What to try first" item 1 now
  that it's done.
- **Retained:** `context/concepts/reference-restructure.md` — refreshed the line counts
  (`config.md` 126, `README.md` 149) after this session's additions to both; the
  restructure itself stays unsettled.
- **Roadmap:** `context/roadmap.toml` — closed `tuning.qwen-context-budget`; `next`
  advances to `tuning.cache-reuse-tuning`.

## Next-focus
tuning.cache-reuse-tuning — turn on `--cache-reuse` (start with a moderate chunk size,
such as 256) and observe prompt eval time / `n_prompt_tokens_cache` across a multi-turn
`pi` session where earlier tool output gets pruned or reordered. Start here next
session.
