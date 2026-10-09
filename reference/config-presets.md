# Model configuration: the preset mechanism

The specification for how per-model configuration works in this repository. See
[`model-tiers.md`](model-tiers.md) for *which* model and *what* it needs; see
[`config-convention.md`](config-convention.md) for the convention this repo layers on top
of this mechanism.

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
