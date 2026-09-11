# reset · personal-agents

- **Status:** closeout
- **Session:** start
- **Branch:** tuning.metrics-and-overhead

## Disposition
- **Integrated:** `research/framework-desktop-followups.md`'s kv-unified sizing and pi
  fixed-overhead sections — both confirmed live this session — moved into
  `reference/config.md`'s new "Observability" and "Memory footprint" sections as durable
  reference; the research doc's "what to try first" list drops the three items this session
  closed out (was 7 items, now 4).
- **Culled:** the measured pi fixed-overhead number itself (`n_prompt_tokens: 1723`) —
  recorded in this session's commits but not promoted anywhere durable; it doesn't
  generalize (will drift as pi's system prompt changes). The qualitative point (context
  growth in a real session is conversation accumulation, not fixed overhead) is what's kept,
  in `reference/config.md`.
- **Retained:** `context/concepts/reference-restructure.md` (new) — captures the idea of
  turning `reference/README.md` into a pure overview/index with its model-selection content
  split into dedicated file(s), and possibly decomposing `reference/config.md` if it keeps
  growing. Raised closing this session; not settled, no session claims it yet.
- **Roadmap:** `context/roadmap.toml` — closed `tuning.metrics-and-overhead` (this session's
  task); added goal `outpost-toolkit` with task `core-commands`, queued immediately next
  (ahead of the remaining `tuning` tasks) per the architect's direction during close —
  `outpost` grows from install-and-restart into a CLI over the router's HTTP API and the
  host's systemd/amdgpu/vulkan tooling. The prior `backlog.outpost-toolkit` evaluation
  (`capabilities/outpost-toolkit.md`) is deleted — superseded by the decision to build it
  now rather than wait for a trigger.

## Next-focus
outpost-toolkit.core-commands — survey llama.cpp's HTTP API, `amdgpu_top`, and related host
tooling for what's worth wrapping; build `outpost server metrics` (formatted `/metrics`
read) and `outpost server models` (list/load/unload against `/models`) at minimum, plus
`amd`/`vulkan` subcommands for whatever else earns its place per the survey. This is new,
open-ended scope raised during this session's close — needs its own SETTLE and stage list
before any code. Start here next session.
