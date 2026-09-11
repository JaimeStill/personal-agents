# RAG / vector search

Previous: [Future capabilities](README.md)

## What it would be

A local vector store — [Chroma](https://www.trychroma.com) or
[Qdrant](https://qdrant.tech) — backing a retrieval-augmented workflow: indexing a corpus,
then handing the model relevant chunks instead of relying on its context window alone.

## Why it doesn't earn its place today

Nothing in the current `pi`-driven workflow does retrieval. `pi` works directly against the
filesystem and the model's own context, and there's no corpus in this setup that needs
indexing yet.

## The two options, and which to reach for first

Chroma is the lower-friction option: it embeds directly in a Python process, no separate
service to run, and comfortably handles up to roughly a million vectors on one machine — a
reasonable ceiling for a personal, single-user corpus. Qdrant runs as its own service even
locally, costs more to stand up, and only pays for itself with quantization and scale
(multi-million-plus vectors) a personal setup isn't likely to reach.

## What would make it worth doing

An actual corpus too large or too unstructured for the model's context window to hold
directly — a growing notes collection, a large codebase beyond what fits in a session, a
document archive. When that shows up, start with Chroma's embedded mode before reaching for
a standalone service like Qdrant.
