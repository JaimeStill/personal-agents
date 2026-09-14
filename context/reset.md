# reset · personal-agents

- **Status:** closeout
- **Session:** start
- **Branch:** tuning.update-restart-hook

## Disposition
- **Integrated:** `research/framework-desktop-followups.md`'s "Does anything restart
  llama-router after an update?" section — the pacman hook it drafted is now installed and
  verified live (`journalctl -u llama-router` and `ActiveEnterTimestamp` both confirm a
  forced `llama-cpp` reinstall restarts the service; an unrelated package's reinstall
  doesn't). Dropped "What to try first" item 4 now that it's done, and fixed item 3's
  forward-reference to it.
- **Integrated:** `admin/README.md`'s tooling summary and `context/README.md`'s "Admin
  tooling (`outpost`)" capability bullet — both now mention the new `outpost hooks install`
  command alongside the tooling it already listed.
- **Roadmap:** `context/roadmap.toml` — closed `tuning.update-restart-hook`; `next`
  advances to `tuning.qwen-context-budget`.

## Next-focus
tuning.qwen-context-budget — add a `[unsloth/Qwen3-Coder-Next-GGUF:Q5_K_M]` section to
`profiles/unified-96gb.ini` with a larger `c` than gpt-oss-120b's, and confirm via
`/props`/`/slots` that it loads and holds the larger window without a proportional memory
jump. Start here next session.
