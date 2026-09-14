# Restructure `reference/` into a pure index plus dedicated files

Raised closing `tuning.metrics-and-overhead`, once that step's findings needed a home in
`reference/config.md` and made its growth visible.

## The idea

`reference/README.md` currently holds both the project's orientation to `reference/` *and*
the model-selection content itself (the "how to reason about it" heuristics and the
by-memory-tier recipes, ~130 lines). The proposal: `README.md` becomes a short overview and
index only, and its current content moves into its own file (or files, if it splits by
concern — reasoning heuristics versus the by-tier catalog).

`reference/config.md` (126 lines as of `tuning.qwen-context-budget`, which added a
"Sizing a model's `c`" section) may warrant the same treatment if it keeps growing —
decomposed by concern (the preset mechanism, the propagation convention, observability,
memory-measurement notes, and now context-budget sizing are five fairly separate topics
sharing one file). `reference/README.md` grew the same way this session (149 lines,
gaining a Qwen3-Coder-Next `c` recipe) — each session that touches `reference/` keeps
adding its findings to the right existing file, exactly the pattern this note already
anticipated below.

## What isn't settled

- Where the split lines fall in `config.md` — whether it's worth decomposing now or only
  once it's demonstrably too large.
- What the model-selection content's new filename(s) should be, and whether "how to reason
  about it" and "by memory tier" split into two files or stay one.
- Whether this is one session's work or naturally falls out of the next few sessions that
  touch `reference/` anyway (each adding its findings to the right file as it goes, per the
  pattern this session just followed for `config.md`).

The architect now considers the split worth doing deliberately rather than waiting for it
to fall out of ordinary sessions: `tuning.qwen-context-budget`'s `c`-sizing findings and
`tuning.checkpoint-tuning`'s caching/checkpoint tuning are exactly the kind of dense,
model-specific result `config.md` and `README.md` need clearly separated homes for, and
`config.md` has grown past 150 lines across five fairly separate topics (the preset
mechanism, the propagation convention, observability, memory measurement, context-budget
sizing, and now caching/checkpoints) since this note was raised. `reference/README.md`'s
dual role is no longer in question; a `plan` session should settle the concrete split
(filenames, where the lines fall) before a `start` session executes it.
