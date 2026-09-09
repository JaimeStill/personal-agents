# The Pi agent harness

Previous: [Networking](networking.md) · Next: [Remote administration](remote-admin.md)

This doc covers installing [`pi`](https://github.com/earendil-works/pi-mono) on the
remote and connecting it to the host's llama.cpp router.

## Install

```bash
mise use -g pi
```

See [`pi`'s own documentation](https://github.com/earendil-works/pi-mono) for alternative
install methods.

## Connect to the router

`pi` has built-in support for a llama.cpp router: it lists, loads, and unloads models
against it, without needing a generic custom-provider configuration. Point it at the
host:

```bash
export LLAMA_BASE_URL=http://<host-tailnet-name>:8080
pi
```

Persist it so it doesn't need re-exporting every session:

```bash
echo 'export LLAMA_BASE_URL=http://<host-tailnet-name>:8080' >> ~/.bashrc
```

Use `~/.bashrc` itself, or another shell rc file that isn't synced by a dotfiles
repository — worth doing if that repo is public, since this references your tailnet's
MagicDNS suffix. Not a security issue (Tailscale's access control doesn't depend on that
name being secret), just a habit of limiting what you publish.

Alternatively, run `/login llama.cpp` inside `pi` and enter the URL interactively; this
persists to `~/.pi/agent/auth.json` instead.

## Load and select a model

If the router was started with `--no-models-autoload` (see
[Hosting setup](hosting-setup.md)), no model is loaded by default, even once connected:

```
/llama
```

opens the router's model list. Selecting an unloaded model loads it; selecting **Download
model…** searches Hugging Face (or accepts an exact `owner/repository[:quant]` string
directly) and has the *host* download it, not the remote. For example, entering:

```
unsloth/Qwen3-Coder-Next-GGUF:Q5_K_M
```

downloads that model to the host, then offers to load it once the download finishes. Once
a model is loaded, run:

```
/model
```

and select it to activate it for the current `pi` session. Only loaded models appear
here.

## Sanity check

Ask `pi` something that requires it to actually use its tools, not just answer from
context, for instance:

```
List the files in this directory and tell me what this project is.
```

Watch for the tool calls themselves (`read`, `ls`/`bash`, etc.) in the output, not just a
plausible-looking final answer. This is the real test of whether the model's chat
template is round-tripping tool calls correctly through `--jinja` — a model can produce
fluent text while silently failing to call tools at all, which won't be obvious from the
final answer alone.

---
Previous: [Networking](networking.md) · Next: [Remote administration](remote-admin.md)
