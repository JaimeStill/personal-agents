# Concept: models/ as host-agnostic reference + administration tooling

Promoted to `goals.models-layout` in `context/roadmap.toml`, ahead of the `tuning` goal —
the layout move happens first so tuning's own follow-on documentation has a settled place to
land, not because per-host duplication has become painful yet.

## The problem

`models/framework-desktop/` bakes host identity into what's largely host-agnostic content.
`models/README.md` and `models/config.md` already treat model selection and the
`--models-preset` INI mechanism as host-agnostic — the mechanism itself doesn't care which
machine runs it. What's actually host-specific is a thin layer: the concrete `.ini` file's
values, and the two scripts that apply and restart it (`install.sh` symlinking the INI into
place, `restart-router.sh` restarting the service). As more hosts get added, that thin layer
duplicates near-identically per host.

## Reference docs still needed

Independent of the tooling question below:

- **GGUF model characteristics** — parameter sizes, quantization levels, and what each
  implies for llama.cpp hosting, as a standing reference rather than scattered through
  `models/README.md`'s per-tier recipes.
- **Model compatibility matrix** — how to identify compatible llama.cpp models on Hugging
  Face: the llama.cpp filter, and which characteristics to check against a target machine's
  hardware constraints.
- **llama.cpp administration guide** — scope not yet settled; likely overlaps
  `setup/remote-admin.md` and `research/framework-desktop-followups.md`'s "Updating
  llama.cpp" section, so this needs reconciling with what already exists, not just adding
  to it, when it's planned.

None of the three are written yet, and don't need to be before the layout settles — where
each belongs depends on the shape `goals.models-layout.tasks.restructure` lands on.

## The tooling question

Whether closing the per-host duplication needs a real CLI (a small Go tool that validates
and applies a profile) or a parameterized shell script is open. The `--models-preset`
mechanism itself needs no new tooling; only the symlink-and-restart scaffolding around it
does. A CLI earns its cost once there's real logic to run — checking a profile against a
host's actual VRAM/GTT before applying it, say; for "symlink this file, restart this
service," a single script parameterized by host name may get most of the benefit without a
new toolchain to build, release, and keep working across machines, in a repo that's
otherwise pure documentation.

## Assumptions

- The layout move is worth doing now, ahead of a second host, because the `tuning` goal's
  own follow-on work needs a place to land — not because duplication has already become
  painful. The Go-CLI-vs-parameterized-script sub-question specifically can still wait for a
  second host to exist; nothing about the layout move itself requires answering it yet.
- The `--models-preset` INI mechanism itself stays llama.cpp's own, unmodified — this is
  about the scaffolding around it, not replacing it.
