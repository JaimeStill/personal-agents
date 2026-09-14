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
- [`../admin/`](../admin/) holds the tooling, dispatched through `outpost` or called
  directly — see [`../admin/README.md`](../admin/README.md) for the commands and
  `../admin/install.sh` to put them on your `PATH`.

This is a manual-propagation convention, not an enforced one — proportionate to a
personal, occasionally-updated setup. It stops being proportionate if this ever grows into
managing many hosts or many concurrently-used models; revisit then, not preemptively.

## Observability: `--metrics`

`metrics = true` in `[*]` turns on a Prometheus-format `/metrics` endpoint per loaded model.
In router mode it needs a `?model={id}` query parameter — a request without one returns
`400`. It exposes token throughput (`llamacpp:prompt_tokens_total`,
`llamacpp:tokens_predicted_total`), request/slot pressure
(`llamacpp:requests_processing`, `llamacpp:requests_deferred`,
`llamacpp:n_busy_slots_per_decode`), and `llamacpp:n_tokens_max` — the largest observed
sequence length, the direct answer to "how much context did a real session actually use."
Confirmed live 2026-09-11 against `profiles/unified-96gb.ini`.

`outpost server metrics <model-id>` wraps this with a formatted summary; spot-check with
`curl` directly for the raw exposition.

## Memory footprint: measure with `amdgpu_top`, not RSS

On unified-memory hardware (a Strix Halo APU, GTT-backed), the GPU memory `llama-server`
holds is invisible to `ps`/`free`-style process RSS — a loaded gpt-oss-120b instance showed
under 200MB of `ps` RSS while actually holding roughly 61GB. Use `amdgpu_top -p` for the
real per-process figure (`VRAM` + `GTT`) — `outpost amd usage` wraps it.

That real figure also confirms `--kv-unified`'s sizing behavior directly: gpt-oss-120b at
`c = 32768` held ~61.2G identically at `total_slots: 4` (`-np` left at its auto default) and
`total_slots: 1` (`-np 1`, tested transiently against a scratch copy of the profile, never
committed) — a 12MB difference, noise against a 61G footprint. The shared KV pool is sized
to `-c` total, not `-c × slots`; slot count carries no meaningful memory cost on this
hardware. `-np` stays at auto in `profiles/*.ini` for this reason — pinning it would trade
away the ability to run a second concurrent `pi` session for no memory savings.

## Sizing a model's `c`

A model's `c` has two independent ceilings: what it was trained to handle, and what the
host's memory affords. Whichever is smaller binds. This is the method behind each
per-model `c` recipe in [`README.md`](README.md); apply it whenever a model's context
budget needs to go beyond `[*]`'s default.

1. **Read the model's trained max context** — the `<arch>.context_length` key in its
   GGUF metadata (no `gguf-dump`-equivalent is installed on this host; a short Python
   script parsing the GGUF header directly, or the model card, both work). Also read its
   KV-cache-relevant architecture: `attention.head_count_kv`, `attention.key_length`,
   `attention.value_length`, and how many layers actually hold a growing KV cache — all
   of them for a plain transformer, but check for a hybrid-attention key like
   `full_attention_interval` on any model that mixes in linear-attention or SSM layers
   (Mamba, Gated DeltaNet): those hold a fixed-size recurrent state that doesn't grow
   with `c` and don't enter this calculation.
2. **Compute the per-token KV cost**: `(key_length + value_length) × head_count_kv × 2
   bytes` (F16; halve again per cache tensor actually quantized via
   `--cache-type-k`/`-v`), summed over only the real-KV-cache layers identified above.
3. **Decide the slot count to provision for.** Use the router's configured `-np`
   (auto-picked; 4 observed on this host, per "Memory footprint" above) unless
   `--kv-unified` behavior has been confirmed for *this specific model* the way it was
   confirmed for gpt-oss-120b above. Without that confirmation, assume conservatively
   that the KV pool multiplies by slot count rather than assuming it's shared.
4. **Compute the memory-derived ceiling**: the usable-memory budget (`README.md`'s
   "Usable memory, not raw memory" — roughly 85-90% of host memory) minus the model's
   weight size minus a compute-buffer safety margin, divided by (per-token KV cost ×
   slots).
5. **`c` = the smaller of the memory-derived ceiling and the trained max context**, kept
   with margin below the trained max even when memory doesn't bind — extrapolating past
   a model's trained context via RoPE scaling is a different, unverified regime, not
   something to reach for just because memory allows it.
