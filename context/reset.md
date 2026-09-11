# reset · personal-agents

- **Status:** closeout
- **Session:** init
- **Branch:** main

## Disposition
- **Retained:** `research/framework-desktop-followups.md` and `capabilities/` — both
  already-settled records this scaffold points into rather than restates.

## Next-focus
models-layout.restructure — settle and apply the host-agnostic `models/` layout (see
`context/concepts/models-tooling.md`): decide the new directory shape separating
host-agnostic reference content from per-host scaffolding, decide or deliberately defer the
Go-CLI-vs-parameterized-script question, and migrate `framework-desktop`'s existing
`install.sh`/`restart-router.sh`/`models.ini` into it, without breaking the router or `pi`.
This goes first so the `tuning` goal's follow-on documentation (starting with
`tuning.metrics-and-overhead`) has a settled place to land. Start here next session.
