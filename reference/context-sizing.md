# Sizing a model's `c`

A model's `c` has two independent ceilings: what it was trained to handle, and what the
host's memory affords. Whichever is smaller binds. This is the method behind each
per-model `c` recipe in [`model-tiers.md`](model-tiers.md); apply it whenever a model's
context budget needs to go beyond `[*]`'s default.

1. **Read the model's trained max context** — the `<arch>.context_length` key in its
   GGUF metadata (no `gguf-dump`-equivalent is installed on this host; a short Python
   script parsing the GGUF header directly, or the model card, both work). Also read its
   KV-cache-relevant architecture: `attention.head_count_kv`, `attention.key_length`,
   `attention.value_length`, and how many layers actually hold a growing KV cache — all
   of them for a plain transformer, but check for a hybrid-attention key like
   `full_attention_interval` on any model that mixes in linear-attention or SSM layers
   (Mamba, Gated DeltaNet): those hold a fixed-size recurrent state that doesn't grow
   with `c` and don't enter this calculation.
2. **Compute the per-token KV cost**: `(key_length + value_length) × head_count_kv × 2
   bytes` (F16; halve again per cache tensor actually quantized via
   `--cache-type-k`/`-v`), summed over only the real-KV-cache layers identified above.
3. **Decide the slot count to provision for.** Use the router's configured `-np`
   (auto-picked; 4 observed on this host, per [`memory-footprint.md`](memory-footprint.md)
   above) unless `--kv-unified` behavior has been confirmed for *this specific model* the
   way it was confirmed for gpt-oss-120b there. Without that confirmation, assume
   conservatively that the KV pool multiplies by slot count rather than assuming it's
   shared.
4. **Compute the memory-derived ceiling**: the usable-memory budget
   ([`model-selection.md`](model-selection.md)'s "Usable memory, not raw memory" —
   roughly 85-90% of host memory) minus the model's weight size minus a compute-buffer
   safety margin, divided by (per-token KV cost × slots).
5. **`c` = the smaller of the memory-derived ceiling and the trained max context**, kept
   with margin below the trained max even when memory doesn't bind — extrapolating past
   a model's trained context via RoPE scaling is a different, unverified regime, not
   something to reach for just because memory allows it.
