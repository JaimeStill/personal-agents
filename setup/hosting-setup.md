# Hosting setup

Next: [Networking](networking.md)

This doc covers installing [llama.cpp](https://github.com/ggml-org/llama.cpp) on the host,
running it in router mode, keeping it running as a service, and giving it somewhere to
keep models.

## Why llama.cpp

llama.cpp is the right default for a single-user host:

- Its Vulkan backend runs against the standard `amdgpu`/Mesa or equivalent GPU userspace
  driver stack already present on most Linux desktops. No vendor compute SDK (ROCm, CUDA)
  install is required to get GPU acceleration.
- Its router mode discovers and loads multiple models on demand, rather than committing
  the process to one model at startup. `pi` (see
  [The Pi agent harness](pi-harness.md)) talks to this router directly.

A vendor compute SDK (ROCm, CUDA) backend can still be faster for some workloads, at the
cost of a heavier, more fragile install. Pick it deliberately if you need it, not by
default.

> **Note:** which backend to install was decided during your host's machine setup under
> `preparation/`; this doc assumes that's already done. For which model fits the
> host's memory, see [`../reference/README.md`](../reference/README.md) — the machine
> setup doc records the specific pick made, but that reference is where the reasoning
> behind it lives.

## Install

Install `llama-server` with a GPU backend for your hardware. On Arch/Omarchy:

```bash
omarchy pkg add llama-cpp
omarchy pkg add ggml-vulkan   # or ggml-cuda, ggml-hip, etc., per your GPU
```

The GPU backend is a separate optional package from the base `llama-cpp`/`ggml` install.
Without it, `llama-server` only has a CPU backend. Confirm the GPU is visible:

```bash
llama-server --list-devices
```

## Model storage

Give models a dedicated location outside `~/models` itself, and symlink `~/models` to it.
The router only ever sees `~/models`; where it actually points is what differs below.

### With a dedicated drive

If a separate drive is available for model storage, format and mount it rather than
sharing the OS drive. Identify it first — this is destructive to whatever's already on
it, so confirm the device name and that it's safe to wipe:

```bash
lsblk -f              # find the drive; confirm it's the right one before continuing
sudo wipefs -n /dev/<drive>   # dry run: reports what would be wiped, changes nothing
```

Partition and format it:

```bash
sudo parted -s /dev/<drive> mklabel gpt
sudo parted -s /dev/<drive> mkpart primary ext4 0% 100%
sudo mkfs.ext4 -L models /dev/<drive>1   # the new partition, e.g. /dev/<drive>p1 on NVMe
```

ext4, not btrfs: no copy-on-write benefit for large, static, mmap-read GGUF files, and
btrfs's COW behavior adds overhead for exactly this access pattern.

Mount it permanently via `/etc/fstab`, rather than a one-off manual mount that won't
survive a reboot:

```bash
sudo blkid /dev/<drive>1                              # note the UUID it prints
sudo mkdir -p /mnt/models
echo 'UUID=<uuid-from-above>  /mnt/models  ext4  defaults,noatime  0  2' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a
sudo chown "$USER":"$USER" /mnt/models
```

A freshly formatted filesystem's root directory contains `lost+found`, owned by `root`
with no group/other access. If `~/models` pointed directly at `/mnt/models`, the router's
directory scan would fail outright the moment it hit that entry
(`Permission denied [.../lost+found]`) — it can't selectively skip a directory it can't
read. Keep `lost+found` out of anything the router walks by putting the actual model data
one level deeper, and symlinking into that instead:

```bash
mkdir -p /mnt/models/gguf /mnt/models/hf-cache
ln -s /mnt/models/gguf ~/models
```

### Without a dedicated drive

No partitioning or mounting needed — just pick a real location with enough free space and
symlink `~/models` to it, the same two-subdirectory shape as above:

```bash
mkdir -p ~/.local/share/models/{gguf,hf-cache}
ln -s ~/.local/share/models/gguf ~/models
```

The symlink is still worth keeping even though there's no separate filesystem to route
around: it keeps `~/models` consistent with the dedicated-drive case above, and leaves
room to move the real data to different storage later without touching the router's
configuration.

### Acquiring models

llama.cpp acquires models two ways, and both belong under the same dedicated storage:

- **Pre-placed files**, discovered by `--models-dir` at startup. A single-file model sits
  directly in the directory; a multi-shard or multimodal model gets its own subdirectory.
- **On-demand Hugging Face downloads** (`--hf-repo`, or `pi`'s own **Download model…**
  flow described in [The Pi agent harness](pi-harness.md)). This path does not use
  `--models-dir` at all — it downloads into the standard Hugging Face cache convention
  (`$HF_HOME/hub/...`, defaulting to `~/.cache/huggingface`) and runs the model from
  there. To keep these downloads on the same dedicated storage as everything else, set
  `HF_HOME` for the router process rather than leaving it at its default on the system
  drive.

## Run the router

Start `llama-server` without `-m`/`--model` — passing a model starts single-model mode
instead. Keep the command line itself to things that aren't model-tunable; everything
that might reasonably differ per model belongs in a preset file instead (see
[Per-model configuration](#per-model-configuration) below), not hardcoded here:

```bash
llama-server \
  --models-dir ~/models \
  --no-models-autoload \
  --host <tailnet-ip> \
  --port 8080 \
  --models-preset ~/models.ini
```

- `--host` binds to the host's Tailscale interface address, not `0.0.0.0` or `127.0.0.1`,
  so only the tailnet can reach it. See [Networking](networking.md) for why no further
  firewalling is needed for this.
- `--no-models-autoload` means a model has to be explicitly loaded (via `/llama` in `pi`,
  or the router's HTTP API) rather than starting automatically. The router still starts
  and answers requests with zero models loaded.
- `--models-preset` points at the INI file carrying everything model-tunable —
  `--jinja`, GPU offload, context size, and any per-model overrides.

## Per-model configuration

`--models-preset` points at an INI file separating defaults every model gets from
overrides a specific model needs — see [`../reference/config.md`](../reference/config.md)
for the full specification, and [`../reference/README.md`](../reference/README.md) for
which models need what. Source-control the preset file alongside everything else in this
repository, so changes are diffable and reversible; [`../profiles/`](../profiles/) holds
the concrete files and [`../admin/`](../admin/README.md) the tooling that symlinks one
into place and restarts the service afterward.

## Run it as a service

A systemd unit keeps the router running across crashes and reboots without a graphical
login:

```ini
[Unit]
Description=llama.cpp router (model server)
After=network-online.target tailscaled.service
Wants=network-online.target
Requires=tailscaled.service

[Service]
Environment=HF_HOME=/path/to/dedicated/storage/hf-cache
Type=simple
User=<user>
ExecStart=/usr/bin/bash -c 'exec /usr/bin/llama-server --models-dir /home/<user>/models --no-models-autoload --host $(tailscale ip -4) --port 8080 --models-preset /path/to/models.ini'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

`--host` resolves the tailnet IP at start time via `$(tailscale ip -4)` inside a shell
wrapper, rather than a hardcoded address, so the unit keeps working if the tailnet IP ever
changes. `Requires=`/`After=tailscaled.service` ensures Tailscale is already up before the
router tries to bind to it.

Install and enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now llama-router
```

## Verify

```bash
curl http://127.0.0.1:8080/health
curl http://<tailnet-ip-or-hostname>:8080/health
```

Both should return `{"status":"ok"}`, confirming the router answers locally and over the
tailnet before moving on to [Networking](networking.md) and
[The Pi agent harness](pi-harness.md).

---
Next: [Networking](networking.md)
