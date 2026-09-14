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

## The settled split

Settled in the `reference-docs.restructure` `plan` session, deliberately rather than
waiting for it to fall out of ordinary sessions: `tuning.qwen-context-budget`'s `c`-sizing
findings and `tuning.checkpoint-tuning`'s caching/checkpoint tuning are exactly the kind of
dense, model-specific result `config.md` and `README.md` needed clearly separated homes
for.

`reference/README.md` becomes a short overview and index only, mirroring
`capabilities/README.md`'s pattern. Its model-selection content splits by concern, since
the by-tier catalog gains entries far more often than the reasoning changes:

| Current section (`README.md`) | New file |
|---|---|
| "How to reason about it" | `reference/model-selection.md` |
| "By memory tier" | `reference/model-tiers.md` |

`reference/config.md` dissolves entirely into five topic files, one per concern, matching
`capabilities/`'s one-file-per-topic convention; `reference/README.md`'s index links each
directly, so no second-level index file is needed:

| Current section (`config.md`) | New file |
|---|---|
| "The mechanism: `--models-preset`" + "The limitation: no grouping" | `reference/config-presets.md` |
| "The convention this repo uses" | `reference/config-convention.md` |
| "Observability: `--metrics`" | `reference/observability.md` |
| "Memory footprint: measure with `amdgpu_top`" | `reference/memory-footprint.md` |
| "Sizing a model's `c`" | `reference/context-sizing.md` |

A `start` session executes this in one pass: the README split, the config.md split, and a
cross-reference sweep — internal links between the moved content (e.g. the by-tier catalog's
Gemma recipe, and the context-sizing method's references into model-selection.md and
memory-footprint.md), the top-level `README.md`'s "Reference" section (currently names
`reference/config.md` directly), and `admin/README.md`'s three links into `config.md` (the
`outpost preset install`, `outpost server metrics`, and `outpost amd usage` entries, into
`config-convention.md`, `observability.md`, and `memory-footprint.md` respectively).
