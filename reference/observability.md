# Observability: `--metrics`

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

Per-request cache/timing detail — how much of a given request's prompt was reused versus
reprocessed — doesn't appear on `/metrics` at all; it's in the completion response itself.
`/v1/chat/completions`'s JSON carries `usage.prompt_tokens_details.cached_tokens` and a
`timings` object (`cache_n`, `prompt_n`, `prompt_ms`). Confirmed live 2026-09-14; see
`../research/framework-desktop-followups.md`'s "How to read reuse from a live request" for
the one gotcha (pin `id_slot` across a multi-turn comparison, or the router's auto slot
assignment can put later turns on an empty slot).
