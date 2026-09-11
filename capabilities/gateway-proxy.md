# Gateway / proxy in front of the router

Previous: [Future capabilities](README.md)

## What it would be

An OpenAI-compatible proxy, such as [LiteLLM](https://github.com/BerriAI/litellm), sitting
between clients and the llama.cpp router. Its job is normalizing multiple backends (local
plus OpenAI plus Anthropic plus Bedrock, say) behind one endpoint, or adding auth,
rate-limiting, or cost-tracking in front of several consumers.

## Why it doesn't earn its place today

`pi` already speaks the router's native protocol directly (`LLAMA_BASE_URL`, per
[`../setup/pi-harness.md`](../setup/pi-harness.md)) — no generic OpenAI-provider config, no
API key layer, nothing a proxy would add for this one client. With a single
tailnet-authenticated router and a single client, there's nothing to normalize and nothing
to gate. Tailscale's device auth already is the access boundary (per
[`../setup/networking.md`](../setup/networking.md)), which is exactly what a gateway would
otherwise need to reinvent.

It's also not free: LiteLLM is a Python process with its own dependency stack, on the order
of a few hundred MB resident before it serves a single request — real weight against a host
that can drop to a few GB free RAM while a big model is loaded, for a layer with no job to
do yet.

## What would make it worth doing

A second consumer of the router that isn't `pi` — a script, another agent harness, or the
browser chat UI in [`browser-chat-ui.md`](browser-chat-ui.md) — needing the same models
through one shared, possibly authenticated, front end. Until then, each client should keep
talking to the router directly.
