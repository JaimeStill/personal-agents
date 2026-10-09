# Memory footprint: measure with `amdgpu_top`, not RSS

On unified-memory hardware (a Strix Halo APU, GTT-backed), the GPU memory `llama-server`
holds is invisible to `ps`/`free`-style process RSS — a loaded gpt-oss-120b instance showed
under 200MB of `ps` RSS while actually holding roughly 61GB. Use `amdgpu_top -p` for the
real per-process figure (`VRAM` + `GTT`) — `outpost amd usage` wraps it. Its header line
gives the pool itself (`GTT used/total MiB`); the router runs each loaded model as its own
`llama-server` process, whose `--alias` in `ps` names the model.

## Set A, measured

This is the measured test from [`model-selection.md`](model-selection.md)'s "Usable
memory, not raw memory". The setup: [`../profiles/unified-96gb.ini`](../profiles/unified-96gb.ini)'s
four models, all loaded on llama.cpp b11529 (Vulkan), with 0, 1, and then 4 requests in
flight on each model (`/slots` confirmed the counts; the embedding model's requests finish
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
