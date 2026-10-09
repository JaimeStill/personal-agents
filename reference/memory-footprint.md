# Memory footprint: measure with `amdgpu_top`, not RSS

On unified-memory hardware (a Strix Halo APU, GTT-backed), the GPU memory `llama-server`
holds is invisible to `ps`/`free`-style process RSS — a loaded gpt-oss-120b instance showed
under 200MB of `ps` RSS while actually holding roughly 61GB. Use `amdgpu_top -p` for the
real per-process figure (`VRAM` + `GTT`) — `outpost amd usage` wraps it. Its header line
gives the pool itself (`GTT used/total MiB`); the router runs each loaded model as its own
`llama-server` process, whose `--alias` in `ps` names the model.

## Set A, measured

This is the measured test from [`model-selection.md`](model-selection.md)'s "Usable
memory, not raw memory". The setup:
[`../profiles/unified-96gb.ini`](../profiles/unified-96gb.ini)'s four models, all loaded on
llama.cpp b11529 (Vulkan), with 0, 1, and then 4 requests in flight on each model (`/slots` confirmed the counts; the embedding model's requests finish
fast enough that 3 of its 4 were in flight at the sample). All figures are `VRAM + GTT`,
in MiB:

| Model | `c` | 0 in flight | 1 in flight | 4 in flight |
|---|---|---|---|---|
| `ggml-org/gpt-oss-120b-GGUF:MXFP4` | 131072 | 65500 | 65500 | 65507 |
| `ggml-org/gemma-4-26B-A4B-it-GGUF:Q4_0` | 32768 | 17367 | 17367 | 17371 |
| `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` | 32768 | 9965 | 9965 | 9967 |
| `ggml-org/embeddinggemma-2-GGUF:Q8_0` | 8192 | 1852 | 1869 | 1869 |
| all four | | 94684 | 94701 | 94714 |
| pool used (with the desktop's ~210MiB) | | 94895 | 94912 | 94926 |
| **pool free, of 98304** | | 3409 (3.33GiB) | 3392 (3.31GiB) | **3378 (3.30GiB)** |

It passes the 3GiB bar. The first attempt didn't: with the 26B-A4B at `c = 65536`
(18084MiB at 4 in flight), the pool had 2669MiB (2.61GiB) free, so its `c` dropped to
32768, per its recipe in [`model-tiers.md`](model-tiers.md).

### The budget, estimated against measured

The same run, at 4 in flight, set beside the estimate
[`context-sizing.md`](context-sizing.md) makes (llama.cpp b11529, the upstream Vulkan x64
build; the 96GiB GTT pool is 98304MiB). Figures in MiB:

| Model | `c` | Weights | KV at `c`, estimated | Compute buffers / other | Estimated | Measured |
|---|---|---|---|---|---|---|
| gpt-oss-120b `MXFP4` | 131072 | 60444 | 4608 | 455 | 65052 | 65507 |
| Gemma 4 26B-A4B `Q4_0` + mmproj `Q8_0` | 32768 | 14696 | 640 | 2035 | 15336 | 17371 |
| gemma-4-E4B `Q8_0` + mmproj `Q8_0` | 32768 | 8183 | 512 | 1272 | 8695 | 9967 |
| EmbeddingGemma 2 `Q8_0` | 8192 | 282 | — | 1587 | 282 | 1869 |
| **set A** | | 83605 | 5760 | 5349 | 89365 (87.27GiB) | 94714 (92.49GiB) |
| pool used, with the desktop's ~210MiB | | | | | | 94926 |
| **pool free, of 98304** | | | | | | **3378 (3.30GiB)** |

- **Weights** are the GGUF file sizes, mmproj included: 63.38GB; 14.61 + 0.80GB;
  8.03 + 0.55GB; 296MB.
- **KV at `c`** is bytes per token × `c`: 36,864, 20,480, and 16,384 bytes per token. The
  26B-A4B's figure counts only its full-attention layers; its sliding-window layers' cache
  (window 1024) lands in the next column. EmbeddingGemma 2 has no estimate.
- **Compute buffers / other** is measured minus weights minus KV: the compute buffers, the
  sliding-window caches, and EmbeddingGemma 2's 8192-token batch (`b = ub = 8192`).
- **Estimated** is weights plus KV, the figure the 85-90% planning estimate in
  [`model-selection.md`](model-selection.md) budgets. Set A's is 90.9% of the pool, just over
  it, and the set still passes the measured test, which is the binding one: at least 3GiB of
  the pool free with every model loaded and 4 requests in flight on each.
- **The first run**, with the 26B-A4B at `c = 65536`, measured 18084MiB for it and 95425MiB
  for the set, leaving 2669MiB (2.61GiB) free: it failed the measured test.
- **The Mistral Small 4 swap** takes gpt-oss-120b and the 26B-A4B out (82878MiB measured) and
  puts Mistral Small 4 in, about 69GiB at `Q4`. That figure is estimated, not measured.

## Slot count costs no memory: `--kv-unified`

The same measurement confirms `--kv-unified`'s sizing for each set-A model: from 0 to 4
requests in flight, no model's footprint grew by more than 17MiB. The KV pool is
allocated at load, sized to `c` total, not `c × slots`, and shared by the 4 slots. An
earlier check on gpt-oss-120b (unsloth `Q4_K_M` at `c = 32768`) found the same from the
other side: ~61.2G at both `total_slots: 4` and `total_slots: 1` (`-np 1`, tested
transiently against a scratch copy of the profile, never committed), a 12MB difference.

Fewer slots would trade away concurrent requests (a second `pi` session, or a consumer
beside it) for no memory savings, so
[`../profiles/unified-96gb.ini`](../profiles/unified-96gb.ini) keeps the 4 slots `-np`'s
auto default picks, pinned as `parallel = 4` with `kv-unified = true`. An explicit
`parallel` turns `--kv-unified`'s auto default off, so the two are set together.
