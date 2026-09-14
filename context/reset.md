# reset · personal-agents

- **Status:** closeout
- **Session:** start
- **Branch:** tuning.cache-reuse-tuning

## Disposition
- **Integrated:** `research/framework-desktop-followups.md`'s "Caching and persistence
  flags" section — replaced the `--cache-reuse` recommendation with a source-confirmed
  finding: the flag is dead code in the installed build (llama-cpp 0.4.0-1, `b10809`), and
  `--ctx-checkpoints` is the actual mechanism behind any non-prefix reuse, untuned at its
  default spacing. Added "How to read reuse from a live request" (the
  `usage.prompt_tokens_details.cached_tokens`/`timings` fields and the `id_slot`-pinning
  gotcha). Also added a short pointer to those fields in `reference/config.md`'s
  Observability section, closing the gap noted at the start of this session.
- **Culled:** `research/framework-desktop-followups.md`'s "What to try first" item 1
  (turn on `--cache-reuse`) — answered negatively, dropped. Added tuning
  `--checkpoint-min-step` as a new, not-yet-attempted item, since it's the real lever this
  session's finding points at.
- **Roadmap:** `context/roadmap.toml` — closed `tuning.cache-reuse-tuning` with that
  negative finding as its disposition; added `tuning.checkpoint-tuning` (tune
  `--checkpoint-min-step` against the same scripted prefix-break comparison) as the task
  this finding points at directly, ahead of the existing `tuning.slot-persistence`.
- **Config:** `profiles/unified-96gb.ini` — `[*]` carries a comment explaining why
  `--cache-reuse` is deliberately absent, so a future session doesn't re-add it without
  the context.

## Next-focus
tuning.checkpoint-tuning — `--cache-reuse` is confirmed dead in this build;
`--ctx-checkpoints` is the only mechanism actually providing non-prefix reuse, untested at
a smaller `--checkpoint-min-step` than the 8192-token default. Script a same-slot-pinned,
multi-turn prefix-break comparison against `/v1/chat/completions` (the same approach this
session used, per `research/framework-desktop-followups.md`'s "How to read reuse from a
live request") against a tuned spacing. Start here next session.
