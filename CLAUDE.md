# personal-agents

This repository is managed by the [marathon](https://github.com/standards-lab/marathon)
workflow. Start here: [`context/README.md`](context/README.md).

**Architecture layer intentionally omitted.** This project's `.claude/marathon.toml`
declares no `architecture/` directory. Marathon core currently treats that layer as
mandatory; this repo omits it deliberately, pending a `marathon-architecture` extension
(not yet built) that makes the layer optional core-wide instead of mandatory. Remove this
note once that extension lands and this repo either enables it or is confirmed not to need
it.
