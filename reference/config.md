# Model configuration

The specification for how per-model configuration works in this repository, and the
convention this repo follows on top of it. [`README.md`](README.md) is where you look up
*which* model and *what* it needs; this doc is *how* that need actually gets applied.

## The mechanism: `--models-preset`

`llama-server`'s router mode reads model-tunable settings from an INI file, pointed to by
`--models-preset PATH` on the router's own command line (see
[`../setup/hosting-setup.md`](../setup/hosting-setup.md)). Two kinds of section exist:

```ini
[*]
jinja = true
n-gpu-layers = 999
c = 32768

[owner/some-model-GGUF:Q4_K_M]
chat-template = chatml
c = 8192
```

- `[*]` applies to every model.
- A section named after a specific model's ID — the same string shown by `/models`, and
  what you'd type into `pi`'s **Download model…** flow — overrides just that one.
- Keys are `llama-server` CLI argument names without the leading dashes.

**Precedence**: a literal CLI flag on the router process outranks anything in the preset
file, including a per-model section. Keep the router's own command line limited to things
that genuinely can't be model-specific (`--host`, `--port`, `--models-dir`,
`--no-models-autoload`, `--models-preset` itself) — anything else belongs in `[*]`, or it
can never be overridden per model.

## The limitation: no grouping

There's no wildcard, glob, comma-separated list, or inheritance mechanism for section
names — confirmed directly against llama.cpp's own documentation. Only exact-match
`[owner/repo:quant]` sections and the single `[*]` global section exist. If three
different quants of the same model family all need the same override (a shared chat
template, say), that override gets duplicated verbatim across three sections — llama.cpp
has no way to deduplicate it for you.

## The convention this repo uses

Given that limitation, keep the *reasoning* in one place and treat each concrete `.ini` as
a set of instantiated copies, not a source of truth in itself:

- [`README.md`](README.md) holds one recipe per model or model family — what override(s)
  it needs and why, organized by memory tier.
- [`../profiles/`](../profiles/)`<tier>.ini` is the concrete file a given host's router
  actually reads, `[*]` plus whichever per-model sections that host currently uses, each
  copied from its README recipe. It's keyed by hardware capability tier — matching this
  doc's own memory-tier headings — not by hostname or device, so a second host in the same
  capability class reuses the same file instead of getting its own copy. A comment above a
  copied section should note which recipe it came from, so a future change to the recipe
  has an obvious set of places to re-propagate to.
- [`../admin/`](../admin/) holds the tooling, dispatched through `outpost` (`outpost
  preset install <tier>`, `outpost service restart`, `outpost service status`) or called
  directly — see [`../admin/README.md`](../admin/README.md) for the commands and
  `../admin/install.sh` to put them on your `PATH`.

This is a manual-propagation convention, not an enforced one — proportionate to a
personal, occasionally-updated setup. It stops being proportionate if this ever grows into
managing many hosts or many concurrently-used models; revisit then, not preemptively.
