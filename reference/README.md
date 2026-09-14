# Reference

A standing reference for the router's model selection and configuration — revisited
whenever the picture changes: new hardware, more memory, or just checking whether a better
model has since emerged. Not a setup step; see [`../setup/`](../setup/) for that.

- [`model-selection.md`](model-selection.md) — how to reason about picking a model for a
  given memory budget: usable memory, dense vs. MoE, quantization, and verifying
  tool-calling.
- [`model-tiers.md`](model-tiers.md) — concrete picks by memory tier, 8GB through
  unified-memory (~90-96GB).
- [`config-presets.md`](config-presets.md) — the `--models-preset` mechanism: how
  per-model overrides work, and llama.cpp's grouping limitation.
- [`config-convention.md`](config-convention.md) — the convention this repo layers on
  top: recipes live here, `profiles/<tier>.ini` holds the instantiated copies.
- [`observability.md`](observability.md) — the `--metrics` endpoint and per-request
  cache/timing detail.
- [`memory-footprint.md`](memory-footprint.md) — measuring real GPU memory use with
  `amdgpu_top` on unified-memory hardware.
- [`context-sizing.md`](context-sizing.md) — the method for sizing a model's `c` against
  its trained context and the host's memory.
