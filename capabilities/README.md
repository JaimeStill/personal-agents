# Future capabilities

A standing reference for capabilities considered but not yet added on top of the running
host/remote setup — parallel to [`../reference/README.md`](../reference/README.md): revisited
when the picture changes (a new need shows up, host headroom changes, a candidate tool
matures) rather than written once and left alone. Each file below evaluates one capability:
what it would take, what it would actually add over the setup as it stands today, and what
would make it worth doing.

[`../research/`](../research/) holds the dated investigations that produced these; this
directory is where the resulting evaluations live on and get revised, since a "hold off for
now" verdict is exactly the kind of thing worth rechecking later rather than only once.

- [`gateway-proxy.md`](gateway-proxy.md) — an OpenAI-compatible proxy (e.g. LiteLLM) in
  front of the router.
- [`rag.md`](rag.md) — local retrieval / vector search (e.g. Chroma, Qdrant).
- [`browser-chat-ui.md`](browser-chat-ui.md) — a browser chat client (e.g. Open WebUI)
  alongside `pi`.
