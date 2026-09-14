# reset · personal-agents

- **Status:** closeout
- **Session:** plan
- **Branch:** reference-docs.restructure

## Disposition
- **Retained:** `context/concepts/reference-restructure.md` — sharpened from open questions
  to the settled split: `reference/README.md` becomes overview+index, its heuristics and
  by-tier catalog move to `model-selection.md` and `model-tiers.md`; `config.md` dissolves
  into five topic files (`config-presets.md`, `config-convention.md`, `observability.md`,
  `memory-footprint.md`, `context-sizing.md`) by concern. Also states the cross-reference
  sweep a `start` session needs: internal links between the moved content, the top-level
  `README.md`'s "Reference" section, and `admin/README.md`'s three links into `config.md`.
  Not promoted to `design/`: this session designed the shape but nothing has built against
  it yet.
- **Roadmap:** `context/roadmap.toml` — sharpened `reference-docs.restructure`'s summary and
  proof to name the settled files above. Not deleted: the task isn't finished, only scoped;
  it stays in `next`, ahead of `tuning.slot-persistence`.

## Next-focus
`reference-docs.restructure` — scoped, ready for a `start` session. Execute the split in
`context/concepts/reference-restructure.md`: author `model-selection.md`, `model-tiers.md`,
`config-presets.md`, `config-convention.md`, `observability.md`, `memory-footprint.md`, and
`context-sizing.md` from their mapped sections, reduce `reference/README.md` to overview+
index over all seven, delete `config.md`, and sweep cross-references (internal links,
top-level `README.md`, `admin/README.md`). `tuning.slot-persistence` follows after.
