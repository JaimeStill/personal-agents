# reset · personal-agents

- **Status:** closeout
- **Session:** start
- **Branch:** tuning.checkpoint-tuning

## Disposition
- **Integrated:** `research/framework-desktop-followups.md`'s "Caching and persistence
  flags" section — replaced the untested `--checkpoint-min-step` note with the confirmed
  finding: `checkpoint-min-step = 4096` (tuned down from the 8192 default), why it was
  chosen over an equally effective `1024` (the 32-checkpoint budget's reach, `32 x
  checkpoint-min-step`, matches Qwen3-Coder-Next's configured `c` at 4096 but only a
  quarter of it at 1024), the live measurements (12/3870 tokens cached at the default vs.
  5122/5170 at 4096, a ~17.7x drop in prompt processing time), and the upstream source
  investigation (the mechanism's SWA-only origin, its generalization to hybrid/recurrent
  architectures, and the still-open PRs refining that generalization's correctness past our
  installed build). Closed out the "What to try first" list to its one remaining item.
- **Retained:** `context/concepts/reference-restructure.md` — added the architect's
  endorsement and this session's (plus `tuning.qwen-context-budget`'s) evidence for it.
  Not promoted to `design/`: the split itself — filenames, where `config.md`'s lines fall —
  isn't settled yet, which is exactly what the next session's `plan` pass is for.
- **Roadmap:** `context/roadmap.toml` — closed `tuning.checkpoint-tuning` with the tuned
  value as its disposition. Added `reference-docs.restructure` (goal `reference-docs`) and
  put it ahead of `tuning.slot-persistence` in `next`, per the architect: the restructure
  should happen before further sessions add more findings on top of `reference/`'s current
  shape.
- **Config:** `profiles/unified-96gb.ini` — `[*]` carries `checkpoint-min-step = 4096` with
  a comment explaining the measurement and the choice over `1024`, matching the existing
  `--cache-reuse` comment's style.

## Next-focus
`reference-docs.restructure` — not yet scoped. Start with a `plan` session (not `start`) to
settle the split of `reference/README.md` (overview + index) and `reference/config.md`
(now five fairly separate topics) per `context/concepts/reference-restructure.md`, before a
later session executes it. `tuning.slot-persistence` follows after.
