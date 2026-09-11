# Framework Desktop follow-ups

The setup documented in `preparation/` and `setup/` is working: the router runs, `pi`
connects to it over Tailscale, and both models load. This is a findings-and-options report
on three questions that setup didn't need to answer — how pi's session context is actually
spent, how `llama-cpp` gets updated, and what else is worth running alongside the router.
Unlike `preparation/`, `setup/`, and `models/`, nothing here is a decided procedure yet; it's
what a live investigation of the running host turned up, for review before acting on any of
it. Findings are current as of September 2026 and tied to this specific host's state at the
time of writing.

## Current state, for reference

The router (`llama-router.service`) runs `llama-server --models-dir /home/jaime/models
--no-models-autoload --host 100.87.194.83 --port 8080 --models-preset
/etc/llama-router/models.ini`, per `setup/hosting-setup.md`. At the time of this
investigation it had `unsloth/gpt-oss-120b-GGUF:Q4_K_M` loaded (not Qwen3-Coder), using
about 41.4G RSS. `/mnt/models` (the dedicated drive) has 758G free of 916G. System RAM is
125Gi total; with that one model loaded, only about 4.1Gi was reported free (about 51Gi
"available," counting reclaimable page cache). No caching, observability, proxy, or
vector-store packages were installed (`redis`, `prometheus`, `grafana`, `litellm`,
`openwebui`, `qdrant`, and `chroma` all absent from `pacman -Q`), and the loaded model's
`/props` response showed `endpoint_metrics: false` — `--metrics` exists as a flag but isn't
turned on.

## Context and session optimization

### Slot count and KV-unified: `c` is the shared budget, not `c × slots`

The router leaves `-np`/`--parallel` at its default (`-1`, auto) — `models/framework-desktop/models.ini`
never sets it — and `--kv-unified`'s own `--help` text defaults it to enabled "if number of
slots is auto," which this is. With `-np` auto, `llama-server` picked `total_slots: 4` for
the loaded gpt-oss-120b instance (confirmed live via `curl http://127.0.0.1:51249/slots`).
Each of the 4 slots reports `n_ctx: 32768`, which looks at first glance like a
131072-token reservation, but that number is each slot's addressable window into one shared
pool, not a per-slot allocation. llama.cpp's own docs describe `--kv-unified` as "a single
unified KV buffer shared across all sequences," and the related `--kv-unified-per-slot`
flag's help text says the shared pool is sized to `n_parallel × N` only when that flag
itself drives the size. Here, `-c 32768` is what's set, so the pool is sized to `-c` (32768)
total, split dynamically across whichever slots are active, not multiplied by 4.

This is corroborated, loosely, by the observed RSS: 41.4G for a Q4_K_M gpt-oss-120b
instance. A 32768-token KV cache at this model's architecture (36 layers, 8 KV heads,
head_dim 64, with roughly half the layers using a 128-token sliding window rather than full
attention) comes to on the order of 1-2GB, which fits comfortably inside 41.4G alongside the
weights. A naive 4× multiplication would only add a few more GB and wouldn't be
distinguishable from RSS alone, so this doesn't prove the reading, but it doesn't contradict
it either. **Confidence: medium-high**, resting on the documentation's wording rather than a
direct before/after memory measurement. A clean test — set `-np 1` explicitly, restart,
diff `/slots` and RSS — would make this certain instead of inferred.

Practical upshot: running 4 auto-picked slots while `pi` only ever drives one sequential
conversation is very likely not costing extra context or memory today, because of
kv-unified — but it isn't proven, and pinning `-np 1` explicitly would make the intended
behavior explicit instead of relying on an auto-picked default.

### Why pi's session shows ~30k against a configured 32768

`pi`'s own README and docs don't mention a token-accounting breakdown, a context-usage
display, or a slash command for either. `~/.pi/agent/settings.json` on this host is minimal
(`{"theme": "omarchy-system"}`) and has nothing context-related. The likely explanation —
fixed overhead from `pi`'s system prompt and tool-call schemas eating into the 32768 window
before conversation even starts — remains a hypothesis, not a confirmed fact. Confirming it
needs either a source-level look at `pi-mono` or an empirical test: start a fresh `pi`
session against this router, send one trivial message, and read `n_prompt_tokens` off
`/slots` immediately. That number is the fixed overhead, directly.

### Model architecture changes the real cost of context, meaningfully

This is the clearest finding of the three. The two models in current use are structurally
very different in how expensive context is to hold:

- **gpt-oss-120b**: 36 hidden layers, 64 attention heads, 8 KV heads (GQA), head_dim 64,
  with attention alternating between full and a 128-token sliding window across layers.
  Every full-attention layer's KV cache grows linearly with context length; the
  sliding-window layers are capped near-constant.
- **Qwen3-Coder-Next**: 48 layers total, but only 12 are standard "Gated Attention" layers
  with a real KV cache (16 query heads / 2 KV heads, GQA); the other 36 are "Gated
  DeltaNet," a linear-attention mechanism that holds a fixed-size recurrent state instead of
  a cache that grows with sequence length.

Qwen3-Coder-Next's context cost scales with only a quarter of its layers, at a narrower KV-head
count (2 versus gpt-oss's 8) on top of that, while gpt-oss-120b's cost scales with roughly
all 36 of its layers, minus whatever the sliding-window layers save. Qualitatively,
Qwen3-Coder-Next is unambiguously far cheaper per token of context than gpt-oss-120b — this
isn't a marginal difference, it's a different order of scaling (constant-per-layer versus
linear-per-layer for three-quarters of the network). An exact head_dim for Qwen3-Coder-Next's
gated-attention layers wasn't pinned down, so treat the direction and rough magnitude as
confirmed, the exact ratio as not computed.

This argues directly for per-model handling in `models/framework-desktop/models.ini` rather
than one shared `[*] c = 32768` (mechanism per `models/config.md`): gpt-oss-120b is the one
that actually needs care around context size and slot count; Qwen3-Coder-Next likely has
real headroom to run a substantially larger `c` at little extra memory cost, which the
current shared setting leaves on the table.

### Caching and persistence flags, against pi's actual usage pattern

`pi` drives one sequential conversation per session, never concurrent requests to the same
model. Against that pattern:

- **`--cache-prompt`** (on by default): directly relevant. This is what lets a follow-up
  message in the same conversation reuse the already-computed KV cache for the unchanged
  prefix instead of reprocessing it — exactly `pi`'s pattern, and it's already on.
- **`--cache-reuse N`** (default 0, off): relevant, currently unused. Lets the server reuse
  cached KV via shifting even when the new prompt isn't a byte-identical prefix of the old
  one — for example, an edited earlier message — worth enabling for a coding-agent workflow
  where tool outputs get pruned or reordered.
- **`--slot-save-path PATH`** (off by default): relevant to the cross-restart case
  specifically. It persists a slot's KV cache to disk so a `pi` session survives a router
  restart (after an update, say — see the next section) without reprocessing the whole
  conversation. Not useful within a single continuous session; useful for exactly the
  restart-recovery scenario `setup/remote-admin.md` already describes.
- **`--cache-ram N`** (default 8192 MiB) and **`--cache-idle-slots`** (on by default,
  requires `--cache-ram`): these govern idle slots being saved to a RAM-backed prompt cache
  and cleared under unified KV. With effectively one active conversation, the other 3
  auto-picked slots sit idle the whole time — this is the mechanism that would keep an idle
  slot's context around without it occupying live GPU KV space, which matters more if `-np`
  stays at auto than if it's pinned to 1.
- **`--ctx-checkpoints`/`--checkpoint-min-step`** (defaults 32 checkpoints, 8192-token
  spacing): mainly a concurrent/multi-client durability feature. Marginal value for a single
  sequential session compared to `--cache-prompt` and `--cache-reuse` above.

Net: `--cache-prompt` (already on) and `--cache-reuse` (off, worth turning on) matter most
for `pi`'s actual pattern. `--slot-save-path` matters specifically for surviving router
restarts. `--cache-ram`/`--cache-idle-slots` and the checkpoint flags matter more if the
4-slot auto layout stays than if `-np` gets pinned to 1.

## Updating llama.cpp

`llama-cpp`, `ggml`, and `ggml-vulkan` are ordinary packages in Arch's official `extra`
repository. Updating them means running `omarchy update`, the same command used for every
other system package, with no separate installer or vendored build involved. A restart is a
separate, manual step: `omarchy update` does not restart `llama-router.service`, so after
any update that touches `llama-cpp`, `ggml`, or `ggml-vulkan`, `sudo systemctl restart
llama-router` is required to actually run the new binary. `extra` already carries
`llama-cpp` 0.4.0-2 (last updated 2026-09-08), one revision ahead of the 0.4.0-1 installed
on this host (installed 2026-09-09, from a build dated 2026-09-04) — the next `omarchy
update` picks it up.

### Does `omarchy update` run a full system package update?

Yes. `/usr/bin/omarchy-update` is the entry point; after logging, locking, confirmation, and
a pre-update snapshot, it calls `omarchy-update-system-pkgs`, which runs:

```
sudo env LC_ALL=C OMARCHY_UPDATE_PACMAN=1 pacman -Syu --noconfirm --overwrite '/usr/share/omarchy/*'
```

That's a full `pacman -Syu` — sync plus sysupgrade, unfiltered. Every installed package from
every enabled repo upgrades together, not a curated subset. The `--overwrite` flag exists
only to let packaged files land in a directory Omarchy also writes unpackaged content into;
it doesn't scope what gets upgraded. AUR packages are handled separately and afterward, by
`omarchy-update-aur-pkgs` (`yay -Sua --noconfirm`), gated on whether any foreign packages are
installed at all. `llama-cpp` itself is `extra`, not AUR, so this stage doesn't apply to it.

`/usr/bin/omarchy-update-pacman-guard` actively blocks a bare `sudo pacman -Syu` run outside
this flow — it detects a sync-plus-sysupgrade pacman invocation from its parent process and
refuses, pointing at `omarchy update` instead. There isn't really a choice of update path on
this system; `omarchy update` is the enforced one.

### Does anything restart llama-router after an update?

No, not automatically. `/usr/bin/omarchy-update-restart` runs at the end of `omarchy update`
and handles exactly four things: a kernel-updated reboot prompt, a Hyprland-updated reboot
prompt, restarting any service named by a `~/.local/state/omarchy/restart-<service>-required`
marker file, and restarting the desktop shell. `llama-router.service` is a hand-authored unit
from `setup/hosting-setup.md`, not an Omarchy-shipped component, so nothing in Omarchy's
packaging ever creates a matching marker for it. It falls into none of the categories
`omarchy-update-restart` checks.

Practical conclusion: after `omarchy update` touches `llama-cpp`, `ggml`, or `ggml-vulkan`,
the old binary keeps running — the systemd service holds its already-mapped executable —
until `sudo systemctl restart llama-router` runs by hand. Worth folding into whatever
routine this project settles on for updates, since nothing will remind you it's needed.

A pacman hook (`/etc/pacman.d/hooks/`) closes this gap without needing to remember it, and
does so precisely — it only fires when one of the named packages is actually part of the
transaction, not on every `omarchy update` run:

```ini
[Trigger]
Operation = Upgrade
Type = Package
Target = llama-cpp
Target = ggml
Target = ggml-vulkan

[Action]
Description = Restarting llama-router after a llama.cpp update...
When = PostTransaction
Exec = /usr/bin/systemctl restart llama-router.service
```

This is ordinary pacman machinery, not something specific to Omarchy — `omarchy update`'s
own guard hook (`/usr/share/libalpm/hooks/00-omarchy-update-guard.hook`) is an existing
example of the same mechanism on this host. Because a pacman hook triggers off the
transaction's actual package list, it restarts the service only on a run that touched one of
these three packages, and does nothing on every other `omarchy update` (Hyprland, waybar,
whatever else) that doesn't. Installing it needs `sudo` and a file under `/etc/pacman.d/hooks/`
— a small, easily reversible change (delete the file), but a live-host change nonetheless,
so it's listed as a "what to try first" item below rather than applied as part of this
report.

### Update cadence: how stale can this get?

Upstream llama.cpp is extremely active — roughly ten tagged builds landed in the 24 hours
before this check, a new build every one to three hours around the clock. No distro package
tracks that in real time, and Arch's `extra` doesn't try to: the build running on this host
(`0.4.0-dev`, upstream build 10809) is roughly 100 builds behind the current upstream tip,
and `extra`'s own package last moved on 2026-09-08. That gap is normal and expected, not a
sign of neglect — treat `extra`'s `llama-cpp` as tracking upstream in periodic snapshots, on
the order of days based on this one data point, not continuously. If a specific upstream fix
or feature is needed sooner than the next `extra` snapshot, that's a "build from source
instead" decision, not something `omarchy update` will get you faster.

### Version-skew risk between llama-cpp and ggml-vulkan

Low, under the normal update path. `pacman -Si llama-cpp` lists an unversioned dependency on
`ggml`, and `ggml-vulkan` depends on unversioned `ggml` too. Both packages come from the same
maintainer with build dates one day apart, suggesting they're published as a coordinated set
even without an explicit version constraint enforcing it. Because `omarchy update` always
runs a full `pacman -Syu` rather than upgrading packages individually, all three move
together on every run. The only way to actually create skew would be a manual partial
upgrade (`sudo pacman -S llama-cpp` alone), which the pacman guard doesn't specifically
block — but that's a general Arch partial-upgrade anti-pattern, not something specific to
this package trio, and isn't the update path this project's docs already point at.

## Additional services

### Observability: `--metrics` first, Prometheus/Grafana only if needed

`llama-server --metrics` turns on a Prometheus-format `/metrics` endpoint, off by default
(confirmed live: `endpoint_metrics: false` on the loaded gpt-oss-120b instance). It exposes
token throughput (`llamacpp:prompt_tokens_total`, `llamacpp:tokens_predicted_total`,
`llamacpp:predicted_tokens_seconds`), request and slot pressure
(`llamacpp:requests_processing`, `llamacpp:requests_deferred`,
`llamacpp:n_busy_slots_per_decode`), and, most relevant to the context questions above,
`llamacpp:n_tokens_max` — the high-water mark of context size actually observed. That last
counter answers "how much context does a real pi session actually use" directly, without
needing a dashboard. In router mode, each query needs a `?model={model_id}` query
parameter or the endpoint returns a 400.

`prometheus` (3.14.0-1) and `grafana` (13.2.1-1) are both in Arch's `extra` repo, no AUR
needed. A single-target Prometheus scraping one `/metrics` endpoint every 15 seconds is a
light process, tens of MB of RAM and negligible CPU; Grafana idles similarly. Both are small
next to the roughly 4.1Gi free while a model is loaded, but neither is free, and turning on
`--metrics` and reading `n_tokens_max`/`requests_deferred` with `curl` or a short script
already answers the concrete question in front of us. Reaching for a dashboard now solves a
problem — watching this over time — that doesn't exist yet.

Plain Prometheus+Grafana is the right-sized choice over a full Grafana LGTM stack
(Loki+Grafana+Tempo+Mimir/Prometheus, typically the `grafana/otel-lgtm` all-in-one image)
for this specifically: Grafana's own docs put LGTM's minimum footprint at 2 CPU cores, 4GB
RAM, and 10GB disk, since it bundles log and trace ingestion nothing in this setup produces
today — llama-server emits no OpenTelemetry traces, and nothing ships its journald output
into Loki. At roughly 4GB minimum, LGTM would consume essentially all of the ~4.1Gi free
while a model is loaded, for two components (Loki, Tempo) sitting idle with zero data
flowing in. That's on the order of 40-80x heavier than plain Prometheus+Grafana for
components this use case has no need for.

**Verdict:** recommend turning on `--metrics` (one flag in `models.ini`) as part of the
context follow-up above; hold off on Prometheus/Grafana until there's an actual need to
watch trends rather than spot-check a number; rule out a full LGTM stack outright unless
logs or traces from something else are actually being collected later.

### Gateway/proxy, browser chat UI, RAG

These three don't have an active case today — see
[`../capabilities/`](../capabilities/README.md) for the standing evaluation of each
(what it would take, and what would make it worth doing), kept there rather than here since
that verdict is worth revisiting over time rather than only at the time of this
investigation.

## What to try first

Roughly in order — each step's result should inform whether the next one is worth doing:

1. **Turn on `--metrics`** in `[*]` in `models.ini` and restart. Cheapest change, unlocks
   real numbers (`n_tokens_max`, `requests_deferred`) for everything below instead of
   inference from RSS and `/slots` alone.
2. **Set `-np 1` explicitly**, restart, and diff `/slots` (should show a single slot) and
   RSS against today's 41.4G baseline for gpt-oss-120b. This directly confirms or refutes
   the kv-unified sizing read above, rather than leaving it inferred.
3. **Send one trivial message in a fresh `pi` session** and read `n_prompt_tokens` off
   `/slots` (or `n_tokens_max` from `/metrics`, once on) immediately after — quantifies the
   fixed system-prompt/tool-schema overhead behind the ~30k-versus-32768 gap.
4. **Add a `[unsloth/Qwen3-Coder-Next-GGUF:Q5_K_M]` section** to `models.ini` with a larger
   `c` than gpt-oss-120b's, and confirm via `/props`/`/slots` that it loads and holds the
   larger window without a proportional memory jump — validates the architecture-driven
   cost difference in practice, and gives Qwen3-Coder-Next the context budget its
   architecture can actually afford.
5. **Turn on `--cache-reuse`** (start with a moderate chunk size, such as 256) and watch
   prompt eval time and `n_prompt_tokens_cache` in the router's logs across a multi-turn
   `pi` session where earlier tool output gets summarized or dropped.
6. **Set `--slot-save-path`** to a directory on the dedicated model-storage drive and verify
   a `pi` session survives an intentional `systemctl restart llama-router` without full
   reprocessing — this is also the piece that makes the "restart after every `llama-cpp`
   update" step below cheap instead of disruptive.
7. **Install the `llama-router` pacman hook** described above, then confirm it by forcing a
   no-op reinstall of `llama-cpp` (`sudo pacman -S llama-cpp`) and checking
   `journalctl -u llama-router` for the restart, rather than waiting for a real upstream
   update to prove it out.
