# personal-agents

## Vision

Documents and evolves a self-hosted LLM setup — a llama.cpp router on a Framework Desktop
host, driven by the `pi` agent harness from a remote machine over Tailscale — and tracks the
follow-on tuning and capability work that keeps it running well, as sequenced, session-sized
steps.

## Capabilities

- **Host setup** — done. [`preparation/`](../preparation/), [`setup/hosting-setup.md`](../setup/hosting-setup.md).
- **Networking** — done. [`setup/networking.md`](../setup/networking.md).
- **Pi harness** — done. [`setup/pi-harness.md`](../setup/pi-harness.md).
- **Remote administration** — done. [`setup/remote-admin.md`](../setup/remote-admin.md).
- **Model selection** — done, standing reference. [`models/`](../models/).
- **Repository layout** (`models/` as host-agnostic reference + administration tooling) —
  in progress, first in sequence. [`roadmap.toml`](roadmap.toml) goal `models-layout`,
  concept in [`context/concepts/models-tooling.md`](concepts/models-tooling.md).
- **Context, update, and observability tuning** — in progress, follows the layout goal.
  [`roadmap.toml`](roadmap.toml) goal `tuning`, findings in
  [`research/framework-desktop-followups.md`](../research/framework-desktop-followups.md).
- **Future capabilities** — tracked, no current trigger. [`capabilities/`](../capabilities/),
  [`roadmap.toml`](roadmap.toml) `backlog`.
