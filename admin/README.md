# outpost

Administration tooling for this repository's `llama-router` setup — applying a profile and
restarting the service today, and wherever this grows next (diagnostics, metadata capture —
see [`../context/roadmap.toml`](../context/roadmap.toml)'s `tuning` goal for what's already
planned there).

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

## Adding a command

Drop a new `outpost-<group>-<verb>` script into [`bin/`](bin/). The dispatcher finds it by
name — nothing to register. Resolve the repo root and this directory the same way the
existing scripts do (`readlink -f` on `${BASH_SOURCE[0]}`, then `dirname`), so the command
still works once it's symlinked elsewhere by `install.sh`.

## Installing

`./install.sh` symlinks everything in `bin/` into `~/.local/bin`, so the commands are
callable from anywhere without `admin/bin/` on your `PATH` directly. Re-run it after
pulling a change that adds or renames a command.
