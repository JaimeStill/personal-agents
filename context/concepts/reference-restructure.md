# Restructure `reference/` into a pure index plus dedicated files

Raised closing `tuning.metrics-and-overhead`, once that step's findings needed a home in
`reference/config.md` and made its growth visible.

## The idea

`reference/README.md` currently holds both the project's orientation to `reference/` *and*
the model-selection content itself (the "how to reason about it" heuristics and the
by-memory-tier recipes, ~130 lines). The proposal: `README.md` becomes a short overview and
index only, and its current content moves into its own file (or files, if it splits by
concern — reasoning heuristics versus the by-tier catalog).

`reference/config.md` (~95 lines after this session's additions) may warrant the same
treatment if it keeps growing — decomposed by concern (the preset mechanism, the
propagation convention, observability, memory-measurement notes are already four fairly
separate topics sharing one file).

## What isn't settled

- Where the split lines fall in `config.md` — whether it's worth decomposing now or only
  once it's demonstrably too large (95 lines isn't yet, by this repo's own standard of
  adding structure when a need shows up, not preemptively).
- What the model-selection content's new filename(s) should be, and whether "how to reason
  about it" and "by memory tier" split into two files or stay one.
- Whether this is one session's work or naturally falls out of the next few sessions that
  touch `reference/` anyway (each adding its findings to the right file as it goes, per the
  pattern this session just followed for `config.md`).

Assumes `reference/README.md`'s dual role (orientation + content) is actually a problem
worth fixing, not just a size the architect is comfortable with — recheck that before
committing effort here.
