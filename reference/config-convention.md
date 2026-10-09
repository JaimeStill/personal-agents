# Model configuration: the convention this repo uses

Given the preset mechanism's limitation — no grouping, no inheritance
([`config-presets.md`](config-presets.md)) — keep the *reasoning* in one place and treat
each concrete `.ini` as a set of instantiated copies, not a source of truth in itself:

- [`model-tiers.md`](model-tiers.md) holds one recipe per model or model family — what
  override(s) it needs and why, organized by memory tier.
- [`../profiles/`](../profiles/)`<tier>.ini` is the concrete file a given host's router
  actually reads, `[*]` plus whichever per-model sections that host currently uses, each
  copied from its recipe there. It's keyed by hardware capability tier — matching
  `model-tiers.md`'s own memory-tier headings — not by hostname or device, so a second
  host in the same capability class reuses the same file instead of getting its own copy. A
  comment above a copied section should note which recipe it came from, so a future change
  to the recipe has an obvious set of places to re-propagate to.
- [`../admin/`](../admin/) holds the tooling, dispatched through `outpost` or called
  directly — see [`../admin/README.md`](../admin/README.md) for the commands and
  `../admin/install.sh` to put them on your `PATH`.

This is a manual-propagation convention, not an enforced one — proportionate to a
personal, occasionally-updated setup. It stops being proportionate if this ever grows into
managing many hosts or many concurrently-used models; revisit then, not preemptively.
