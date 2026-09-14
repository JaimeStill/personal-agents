# reset · personal-agents

- **Status:** closeout
- **Session:** start
- **Branch:** reference-docs.restructure

## Disposition
- **Integrated:** `context/concepts/reference-restructure.md` — deleted; the split it
  scoped is now built and validated: `reference/README.md` split into `model-selection.md`
  and `model-tiers.md`, `reference/config.md` dissolved into `config-presets.md`,
  `config-convention.md`, `observability.md`, `memory-footprint.md`, and
  `context-sizing.md`, and every cross-reference into the two dissolved targets repointed
  — top-level `README.md`, `admin/README.md`, `preparation/framework-desktop.md`,
  `setup/hosting-setup.md`, and `research/framework-desktop-followups.md`.
- **Roadmap:** `context/roadmap.toml` — deleted goal `reference-docs` and its task
  `restructure` (both criteria met, no tasks remain under the goal); `next` advances to
  `tuning.slot-persistence` alone.

## Next-focus
`tuning.slot-persistence` — set `--slot-save-path` to a directory on the dedicated
model-storage drive and verify a `pi` session survives an intentional `llama-router`
restart without full reprocessing, per `context/roadmap.toml`'s existing task and the
"What to try first" section of `research/framework-desktop-followups.md`.
