# reset · personal-agents

- **Status:** closeout
- **Session:** start
- **Branch:** models-layout.restructure

## Disposition
- **Culled:** `context/concepts/models-tooling.md` — its open questions (tooling shape,
  host-scoped vs. capability-scoped config, naming) are settled and enacted as the actual
  repo structure: `reference/` (host-agnostic docs), `admin/` (the `outpost` dispatcher and
  its commands), `profiles/` (per-capability-tier `.ini` files). `models/` is retired.

## Next-focus
tuning.metrics-and-overhead — turn on `--metrics` in `profiles/unified-96gb.ini`'s `[*]`
section, pin `-np 1` explicitly, restart via `outpost service restart`, and measure
`/slots` + RSS against the current 4-slot/41.4G baseline (see
`research/framework-desktop-followups.md`, "What to try first" steps 1-2). Separately
measure a fresh `pi` session's fixed `n_prompt_tokens` overhead against the configured
32768 `c`. Start here next session.
