# Personal agents

This repository documents running a self-hosted LLM on one machine and driving it with the
[Pi agent harness](https://github.com/earendil-works/pi-mono) from another, over a private
[Tailscale](https://tailscale.com) network. It targets [Omarchy](https://omarchy.org) as
the distro on both machines; steps specific to Omarchy are called out where they occur
rather than assumed silently.

## Host and remote

Two roles recur throughout these docs:

- The **host** is the machine that serves models. It runs a llama.cpp router as a
  standing service and does the actual inference. It's expected to be a stationary
  machine with a capable GPU or a large-unified-memory APU.
- The **remote** is the machine you work from. It runs `pi` and connects to the host
  over Tailscale. It does no local inference.

A single physical pair fills these roles today (see [Preparation](#1-preparation) below),
but the `setup/` guides are written in host/remote terms throughout, not tied to specific
hardware, so the same steps apply if either role moves to different machines later.

## Setup sequence

### 1. Preparation

Before touching `setup/`, check whether your hardware needs preliminary, device-specific
work under `preparation/`. Only devices that actually require something beyond the
general `setup/` steps get a file here — most remotes, for instance, don't. A second unit
of an already-documented device still gets its own file rather than reusing one, even with
identical silicon, so whatever actually differs between two nominally identical machines
(firmware revision, BIOS defaults, anything else that turns up) gets caught rather than
silently assumed away.

- [`preparation/framework-desktop.md`](preparation/framework-desktop.md) — the Framework
  Desktop acting as host today.

If your hardware isn't listed and needs something device-specific the general docs don't
cover, write it down here, following the pattern of the existing file, once you've worked
it out.

### 2. Setup

With preparation settled, follow `setup/` in order:

1. [Hosting setup](setup/hosting-setup.md) — installing and running the llama.cpp router
   on the host, as a systemd service, with model storage and acquisition.
2. [Networking](setup/networking.md) — Tailscale prerequisites, exposing the host on the
   tailnet, and enabling remote terminal access.
3. [The Pi agent harness](setup/pi-harness.md) — installing `pi` on the remote and
   connecting it to the host's router.
4. [Remote administration](setup/remote-admin.md) — managing the host from the remote:
   terminal sessions, file transfer, updates, and restart recovery.

Each doc links to the next and previous in this order.

## Reference

[`reference/`](reference/README.md) isn't a setup step — it's a standing reference for
picking a model against a given host's memory budget, and the specification for how
per-model configuration actually gets applied
([`reference/config-presets.md`](reference/config-presets.md)). Revisit it whenever the
picture changes: new hardware, more memory, or just checking whether a better model has
since emerged. Each host's concrete configuration lives under [`profiles/`](profiles/) as
`<tier>.ini`, keyed by hardware capability tier rather than device (e.g.
[`profiles/unified-96gb.ini`](profiles/unified-96gb.ini) — see
`reference/config-convention.md` for what a tier is), so hosts in the same capability
class share a file. [`admin/`](admin/README.md) is the tooling that applies and restarts
it (`outpost
preset install <tier>`, `outpost service restart`).

[`capabilities/`](capabilities/README.md) is a similar standing reference, one file per
capability considered but not yet added on top of the running setup (a gateway/proxy, RAG,
a browser chat UI) — what it would take, and what would make it worth doing.
[`research/`](research/) holds the dated investigations (host state, live measurements,
options considered) that back both `reference/` and `capabilities/`'s current calls.
