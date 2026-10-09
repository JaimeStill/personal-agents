# Memory footprint: measure with `amdgpu_top`, not RSS

On unified-memory hardware (a Strix Halo APU, GTT-backed), the GPU memory `llama-server`
holds is invisible to `ps`/`free`-style process RSS — a loaded gpt-oss-120b instance showed
under 200MB of `ps` RSS while actually holding roughly 61GB. Use `amdgpu_top -p` for the
real per-process figure (`VRAM` + `GTT`) — `outpost amd usage` wraps it.

That real figure also confirms `--kv-unified`'s sizing behavior directly: gpt-oss-120b at
`c = 32768` held ~61.2G identically at `total_slots: 4` (`-np` left at its auto default) and
`total_slots: 1` (`-np 1`, tested transiently against a scratch copy of the profile, never
committed) — a 12MB difference, noise against a 61G footprint. The shared KV pool is sized
to `-c` total, not `-c × slots`; slot count carries no meaningful memory cost on this
hardware. Fewer slots would trade away concurrent requests (a second `pi` session, or a
consumer beside it) for no memory savings, so
[`../profiles/unified-96gb.ini`](../profiles/unified-96gb.ini) keeps the 4 slots auto
picked, pinned as `parallel = 4` with `kv-unified = true` — an explicit `parallel` turns
`--kv-unified`'s auto default off, so the two are set together.
