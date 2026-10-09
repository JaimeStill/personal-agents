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
investigation it had `unsloth/gpt-oss-120b-GGUF:Q4_K_M` loaded (not Qwen3-Coder); see
[`../reference/memory-footprint.md`](../reference/memory-footprint.md) for its real
memory footprint and why `ps`/`free`-style RSS reads far too low on this hardware.
`/mnt/models` (the dedicated
drive) has 758G free of 916G. System RAM is 125Gi total; with that one model loaded, only
about 4.1Gi was reported free (about 51Gi "available," counting reclaimable page cache). No
caching, observability, proxy, or vector-store packages were installed (`redis`,
`prometheus`, `grafana`, `litellm`, `openwebui`, `qdrant`, and `chroma` all absent from
`pacman -Q`).

## Context and session optimization

`c` is the shared context budget, not `c × slots`, and `pi`'s fixed per-message overhead is
small (both confirmed — see
[`../reference/memory-footprint.md`](../reference/memory-footprint.md)). What's left open:

### Model architecture changes the real cost of context, meaningfully

The two models in current use are structurally very different in how expensive context is
to hold:

- **gpt-oss-120b**: 36 hidden layers, 64 attention heads, 8 KV heads (GQA), head_dim 64,
  with attention alternating between full and a 128-token sliding window across layers.
  Every full-attention layer's KV cache grows linearly with context length; the
  sliding-window layers are capped near-constant.
- **Qwen3-Coder-Next**: 48 layers total, but only 12 are standard "Gated Attention" layers
  with a real KV cache (16 query heads / 2 KV heads, GQA); the other 36 are "Gated
  DeltaNet," a linear-attention mechanism that holds a fixed-size recurrent state instead of
  a cache that grows with sequence length.

**Update, now confirmed against the GGUF metadata directly** (`qwen3next.*` keys —
`head_count_kv = 2`, `key_length = value_length = 256`): the per-token KV cost is
`(key_length + value_length) × head_count_kv × 2 bytes` — identically **2048
bytes/token/layer** for both models (Qwen: `(256+256) × 2 × 2`; gpt-oss:
`(64+64) × 8 × 2`, its confirmed head_dim=64/8 KV heads). The "narrower KV-head count...
on top of that" framing below was wrong — the narrower head count and the wider
key/value length cancel out exactly. All of Qwen3-Coder-Next's saving comes from having
a smaller fraction of its layers actually hold a growing KV cache: 12 of 48 (25%,
`full_attention_interval = 4`) versus gpt-oss's roughly 18 of 36 (50%, alternating
full/sliding-window). That's a real **1.5x per-token saving**, not "a different order of
scaling" as the original paragraph below claimed — correcting that overstatement here
rather than rewriting the reasoning that led to it:

Qwen3-Coder-Next's context cost scales with only a quarter of its layers, while
gpt-oss-120b's cost scales with roughly half of its 36, minus whatever the
sliding-window layers save. Qualitatively, Qwen3-Coder-Next is cheaper per token of
context than gpt-oss-120b, though the effect is the full-attention-layer fraction, not
an order-of-magnitude difference (constant-per-layer versus linear-per-layer for a
quarter versus half of each network, respectively).

This argues directly for per-model handling in `profiles/unified-96gb.ini` rather
than one shared `[*] c = 32768` (mechanism per `reference/config-presets.md`):
gpt-oss-120b is the one that actually needs care around context size and slot count;
Qwen3-Coder-Next has real
headroom to run a substantially larger `c` at little extra memory cost, which the
current shared setting leaves on the table. **Confirmed live** (see "What to try first"
below): at `c = 131072` (4x gpt-oss's value, half Qwen3-Coder-Next's trained 262144),
the loaded instance holds ~56.6GiB total (`amdgpu_top`: 8MiB VRAM + 57946MiB GTT)
against a ~53GiB weight footprint — roughly 3.6GiB of KV cache and compute buffers for a
4x larger context window, not a proportional jump.

### Caching and persistence flags, against pi's actual usage pattern

`pi` drives one sequential conversation per session, never concurrent requests to the same
model. Against that pattern:

- **`--cache-prompt`** (on by default): directly relevant. This is what lets a follow-up
  message in the same conversation reuse the already-computed KV cache for the unchanged
  prefix instead of reprocessing it — exactly `pi`'s pattern, and it's already on.
- **`--cache-reuse N`** (default 0, off): **dead in this build, confirmed against source.**
  The flag's own `--help` text still describes it as "min chunk size to attempt reusing from
  the cache via KV shifting," and every write-up of it online describes shifting a matching
  chunk into place even when it isn't a byte-identical prefix. Turning it on and testing
  against a scripted prefix-breaking edit (`tuning.cache-reuse-tuning`) showed no such reuse
  at any chunk size — every request hit `cached_tokens: 19` (just the trivial common-prefix
  boundary) regardless of whether `--cache-reuse` was set at all. The router's own
  `system_fingerprint` (`b10809-5266f24da7`) pins the exact upstream commit; fetching every
  file under `tools/server/` at that commit and searching for `cache_reuse`/`n_cache_reuse`
  turns up only two guard warnings in `server-context.cpp` that force it to `0` under
  multimodal or an unsupported context type — no chunk-matching or KV-shift code exists
  anywhere in the server at this commit. The flag parses and prints at startup; it does
  nothing. Whatever reuse a request gets for a non-prefix edit comes entirely from the
  context-checkpoint mechanism below, not from this flag.
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
- **`--ctx-checkpoints`/`--checkpoint-min-step`** (32 checkpoints, `checkpoint-min-step =
  4096` in `profiles/unified-96gb.ini`, tuned down from the 8192 default): **the mechanism
  behind any non-prefix reuse**, not a marginal concurrent-client feature as first assessed
  below — the live test's `restored context checkpoint (pos_min=18, pos_max=18,
  n_tokens=19, n_past=19)` log line is this feature firing, not `--cache-reuse`. It
  originated upstream as SWA-only checkpointing ([PR
  #15293](https://github.com/ggml-org/llama.cpp/pull/15293), bounded by the SWA window
  size) and was later generalized to hybrid/recurrent architectures — the mechanism
  Qwen3-Coder-Next's 36 Gated DeltaNet layers need, since a recurrent state can't be
  truncated back like an ordinary causal KV cache. A checkpoint only ever lands at the
  trivial common-prefix boundary when the stable prefix before an edit is shorter than
  `checkpoint-min-step`; once the prefix clears the spacing, reuse is near-total. Measured
  live against a same-slot-pinned prefix-break comparison (methodology below): at the 8192
  default, a ~3870-token stable prefix got 12/3870 tokens cached (~6.1s prompt
  processing); at 4096, a ~5170-token prefix got 5122/5170 cached (~350ms — a ~17.7x drop).
  4096 was chosen over an equally effective 1024 because the checkpoint budget's reach is
  `32 x checkpoint-min-step`: 4096 matches that reach (131072) exactly to Qwen3-Coder-Next's
  configured `c`, where 1024's reach (32768, a quarter of it) risks evicting early
  checkpoints in a long session. The checkpoint-restored completion was verified
  byte-correct against a cold run. Several upstream PRs refining hybrid/recurrent
  checkpoint correctness and eviction policy (e.g. [#24899](https://github.com/ggml-org/llama.cpp/pull/24899),
  [#25592](https://github.com/ggml-org/llama.cpp/pull/25592)) are still open as of this
  writing, postdating the installed build (0.4.0-dev, build 10809) — no correctness or
  memory issue was observed in live testing, but this area of llama.cpp is still moving.

Net: `--cache-prompt` (already on) handles pure prefix growth. `--cache-reuse` does nothing
in this build regardless of setting — leave it unset. `--ctx-checkpoints`/
`--checkpoint-min-step` is the mechanism that actually matters for `pi`'s prune-and-reorder
pattern, and is now tuned (`checkpoint-min-step = 4096`). `--slot-save-path` matters
specifically for surviving router restarts. `--cache-ram`/`--cache-idle-slots` matter more
if the 4-slot auto layout stays than if `-np` gets pinned to 1.

### How to read reuse from a live request

`GET`/`POST` against `/v1/chat/completions` (and presumably the native `/completion`
endpoint) exposes exactly what a session needs to check reuse, no extra flag or log
verbosity required: `usage.prompt_tokens_details.cached_tokens` and a `timings` object with
`cache_n` (tokens reused), `prompt_n` (tokens actually reprocessed), and `prompt_ms`.
Confirmed live 2026-09-14. One easy-to-miss requirement: the router auto-assigns each
request to whichever of its idle slots is free, so a multi-turn comparison must pin every
request to the same slot with `"id_slot": N` in the request body — otherwise a later turn
can land on a slot with no prior history at all, showing zero reuse for a reason that has
nothing to do with any caching flag.

This session's test script (not kept in the repo) sent a cold multi-turn exchange with two
large "tool output" blocks, then replayed the same history with the first block pruned to
a placeholder, comparing `cached_tokens`/`prompt_ms` on the resulting prefix-break request.
That request shape doesn't depend on `--cache-reuse` specifically — the same approach
applies unchanged to any server-side caching flag under test, one run per config value,
each right after a fresh restart and model load.

## Updating llama.cpp

> **Superseded (October 2026):** the router no longer runs Arch's packages. It runs
> upstream's Vulkan release from a versioned directory under `/opt/llama.cpp/`, updated by
> hand, restart included — see
> [`../setup/hosting-setup.md`](../setup/hosting-setup.md#updating-to-a-newer-build). The
> packages and the pacman hook described below are removed from the host, and the hook and
> its `outpost` install command are retired from this repository. The findings stay as the
> record of why the packaged path was set aside: it trailed upstream by about a hundred
> builds.

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
transaction, not on every `omarchy update` run. It was tracked in this repo as
`hooks/llama-router-restart.hook` and installed with `outpost hooks install`, both since
retired:

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
whatever else) that doesn't.

Installed and verified live on this host: a forced `sudo pacman -S llama-cpp` reinstall
restarted `llama-router.service` (`journalctl -u llama-router` and its
`ActiveEnterTimestamp` both moved to the reinstall's timestamp), and a forced reinstall of
an unrelated, already-installed package (`jq`) left the service's `ActiveEnterTimestamp`
and log untouched — the `Target` filter holds, not just the `Exec` line.

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

### Observability: `--metrics` is on; Prometheus/Grafana only if needed

`--metrics` is on — see [`../reference/observability.md`](../reference/observability.md)
for the mechanism and what it exposes. What's still open is whether
anything should consume it continuously.

`prometheus` (3.14.0-1) and `grafana` (13.2.1-1) are both in Arch's `extra` repo, no AUR
needed. A single-target Prometheus scraping one `/metrics` endpoint every 15 seconds is a
light process, tens of MB of RAM and negligible CPU; Grafana idles similarly — both small
next to the roughly 4.1Gi free while a model is loaded, but neither is free, and a `curl`
spot-check already answers the concrete question in front of us today. Reaching for a
dashboard solves a problem — watching this over time — that doesn't exist yet.

Plain Prometheus+Grafana is the right-sized choice over a full Grafana LGTM stack
(Loki+Grafana+Tempo+Mimir/Prometheus, typically the `grafana/otel-lgtm` all-in-one image)
for this specifically: Grafana's own docs put LGTM's minimum footprint at 2 CPU cores, 4GB
RAM, and 10GB disk, since it bundles log and trace ingestion nothing in this setup produces
today — llama-server emits no OpenTelemetry traces, and nothing ships its journald output
into Loki. At roughly 4GB minimum, LGTM would consume essentially all of the ~4.1Gi free
while a model is loaded, for two components (Loki, Tempo) sitting idle with zero data
flowing in. That's on the order of 40-80x heavier than plain Prometheus+Grafana for
components this use case has no need for.

**Verdict:** hold off on Prometheus/Grafana until there's an actual need to watch trends
rather than spot-check a number; rule out a full LGTM stack outright unless logs or traces
from something else are actually being collected later. `outpost server metrics` now wraps
the spot-check (`admin/README.md`).

### Gateway/proxy, browser chat UI, RAG

These three don't have an active case today — see
[`../capabilities/`](../capabilities/README.md) for the standing evaluation of each
(what it would take, and what would make it worth doing), kept there rather than here since
that verdict is worth revisiting over time rather than only at the time of this
investigation.

## What to try first

**Set `--slot-save-path`** to a directory on the dedicated model-storage drive and verify a
`pi` session survives an intentional `systemctl restart llama-router` without full
reprocessing — this is also the piece that makes the restart after every llama.cpp update
(see "Updating llama.cpp" above) cheap instead of disruptive. Not attempted
yet (`tuning.slot-persistence`).
