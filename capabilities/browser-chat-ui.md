# Browser chat UI

Previous: [Future capabilities](README.md)

## What it would be

[Open WebUI](https://github.com/open-webui/open-webui) (or a lighter alternative) as a
second client against the already-running router, reachable from a phone or another
Tailscale device — reusing whatever model is already loaded rather than loading its own.

## Why it's ready whenever it's wanted

Open WebUI talks to any OpenAI-compatible endpoint directly (an admin connection setting for
URL and optional API key, auto-detecting models via `/models`) — it doesn't need
[`gateway-proxy.md`](gateway-proxy.md) in front of it, since the router's own port already
speaks that protocol. Docker is already installed on the Framework Desktop, which is Open
WebUI's primary distribution path — a `docker run` away, no new package manager or runtime
to bring in. A non-Docker install also exists (`uvx open-webui@latest serve`), but `uv`
isn't currently installed on this host, so Docker is the lower-friction path here
specifically. Either way it's a modest, mostly-idle web process; the real cost is the
browser tab, not the server.

## What would make it worth doing

An actual want to chat with the hosted models from somewhere other than `pi` — a phone, a
second device on the tailnet. Unlike [`gateway-proxy.md`](gateway-proxy.md) and
[`rag.md`](rag.md), there's no missing precondition here; this is a "when you want it," not
a "why don't we have it yet."
