# reset · personal-agents

- **Status:** closeout
- **Session:** start
- **Branch:** outpost-toolkit.core-commands

## Disposition
- **Integrated:** dropped `CLAUDE.md`'s "architecture layer intentionally omitted" note —
  the condition it named landed mid-session: the marathon plugin update to 0.12.0 no longer
  requires a workspace coordinator to declare `[workspace] architecture`
  (`mechanics/configuration.md`); the layer is optional core-wide now, not pending a
  not-yet-built extension.
- **Integrated:** `research/framework-desktop-followups.md`'s "Additional services" section
  called `outpost server metrics` "queued" — updated now that it's built.
- **Roadmap:** `context/roadmap.toml` — closed `outpost-toolkit.core-commands`; the
  `outpost-toolkit` goal closes with it (its only task, criteria now hold). Survey against
  the live router and host (this machine turns out to be the Framework Desktop host itself)
  found `GET /models`, `POST /models/load`/`/models/unload` (undocumented by `--help`,
  confirmed against llama.cpp's own `tools/server/README.md`), `GET /metrics?model=<id>`,
  and `amdgpu_top -p` worth wrapping; nothing Vulkan-specific earned a subcommand
  (`--list-devices` already a one-liner, `vulkaninfo` not installed) — per the architect's
  direction, that's simply not built, untracked. `next` advances to
  `tuning.update-restart-hook`.

## Next-focus
tuning.update-restart-hook — install the pacman hook (already drafted in
`research/framework-desktop-followups.md`) targeting `llama-cpp`, `ggml`, and
`ggml-vulkan`, and verify it fires only on a transaction touching one of them (a forced
`sudo pacman -S llama-cpp` reinstall should trigger `systemctl restart llama-router`,
visible in `journalctl -u llama-router`; an unrelated package update should not). Start
here next session.
