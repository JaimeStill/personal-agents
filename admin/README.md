# outpost

Administration tooling for this repository's `llama-router` setup: applying a profile and
managing the systemd service, querying the router's HTTP API, and reading the host's GPU
usage — see [`../context/roadmap.toml`](../context/roadmap.toml) for what's planned next.

## The name

A host running this setup is administered remotely, over Tailscale, from wherever the
architect actually sits — an outpost, not a workstation sat at directly.

## Commands

Run through the `outpost` dispatcher, or call the underlying script directly — both work
the same way:

- `outpost preset install <tier>` (`outpost-preset-install`) — symlinks
  [`../profiles/`](../profiles/)`<tier>.ini` into the location the `llama-router` systemd
  unit reads from. See [`../reference/config.md`](../reference/config.md) for what a tier
  is and how profiles are organized.
- `outpost service restart` (`outpost-service-restart`) — restarts `llama-router.service`
  and shows its status.
- `outpost service status` (`outpost-service-status`) — shows the service's systemd status
  and a `/health` check, without restarting anything. No `sudo` needed.
- `outpost server models` (`outpost-server-models`) — lists the router's registered models
  with status and context size (`GET /models`). `outpost server models load <model-id>` /
  `models unload <model-id>` load or unload one (`POST /models/load` / `/models/unload`).
- `outpost server metrics <model-id>` (`outpost-server-metrics`) — a formatted read of
  `GET /metrics?model=<id>`: prompt/generation throughput, request/slot pressure, and
  `n_tokens_max`. The model id is mandatory; run `outpost server models` to find one. See
  [`../reference/config.md`](../reference/config.md)'s "Observability" section for what the
  endpoint exposes.
- `outpost amd usage` (`outpost-amd-usage`) — per-process VRAM/GTT via `amdgpu_top -p`, the
  way to see what `llama-server` actually holds on unified-memory hardware, where
  `ps`/`free`-style RSS reads far too low. See
  [`../reference/config.md`](../reference/config.md)'s "Memory footprint" section.
- `outpost hooks install` (`outpost-hooks-install`) — symlinks every pacman hook in
  [`../hooks/`](../hooks/) into `/etc/pacman.d/hooks/`, the same tracked-file-symlinked-
  into-place pattern `outpost preset install` uses for `profiles/`.

## Adding a command

Drop a new `outpost-<group>-<verb>` script into [`bin/`](bin/). The dispatcher finds it by
name — nothing to register. Resolve the repo root and this directory the same way the
existing scripts do (`readlink -f` on `${BASH_SOURCE[0]}`, then `dirname`), so the command
still works once it's symlinked elsewhere by `install.sh`.

## Installing

`./install.sh` symlinks everything in `bin/` into `~/.local/bin`, so the commands are
callable from anywhere without `admin/bin/` on your `PATH` directly. Re-run it after
pulling a change that adds or renames a command.
