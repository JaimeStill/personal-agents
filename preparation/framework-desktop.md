# Host: Framework Desktop

Framework Desktop, AMD Ryzen AI Max ("Strix Halo") APU, 128GB unified RAM, running
Omarchy. A second Framework Desktop still gets its own file here, even with identical
silicon — documenting by device rather than by chip catches whatever actually differs
between two nominally identical units (firmware revision, BIOS defaults, anything else
that turns up) instead of silently assuming they match.

Strix Halo's unified memory means the GPU's usable memory is a software configuration,
not a fixed hardware limit. The steps below get that configuration right before starting
[`setup/hosting-setup.md`](../setup/hosting-setup.md) — getting it wrong the first time
took real troubleshooting, so the detail here is worth keeping even after it's working.

## Steps

1. **Enter BIOS (`F2` at boot) and set the GPU memory reservation to `Custom: 512MB`**,
   down from the default `Auto`. This follows AMD's own guidance for this chip: keep the
   BIOS's fixed reservation small, and set the real ceiling at the OS level instead (the
   remaining steps). `Auto`'s actual behavior isn't guaranteed stable across firmware
   updates; an explicit small value is deterministic.

2. **Install `amd-debug-tools` and set the GTT ceiling:**
   ```bash
   omarchy pkg add amd-debug-tools
   sudo amd-ttm --set 96
   ```
   This queues the change rather than applying it — it writes `options ttm
   pages_limit=25165824` to `/etc/modprobe.d/ttm.conf`, which only takes effect the next
   time the `ttm` kernel module loads, at early boot (step 4).

3. **Add the matching `amdgpu` parameter by hand:**
   ```bash
   echo 'options amdgpu gttsize=98304' | sudo tee /etc/modprobe.d/amdgpu.conf
   ```
   `ttm.pages_limit` (step 2) is a ceiling shared by the whole TTM subsystem; `gttsize` is
   what `amdgpu` itself actually *advertises* to userspace (Vulkan, and so `llama-server
   --list-devices`) as available memory. It has to match the ceiling, or `amdgpu` gets
   clamped or hits allocation failures. 96GB × 1024 = 98304 MB.

4. **Rebuild the boot image with `limine-mkinitcpio`, then reboot:**
   ```bash
   sudo limine-mkinitcpio
   sudo reboot
   ```
   Both parameters above only take effect once embedded in the initramfs run at early
   boot — writing them alone changes nothing until the image is rebuilt. Omarchy boots via
   a Unified Kernel Image (`/boot/EFI/Linux/omarchy_linux.efi`, loaded by
   [Limine](https://limine-bootloader.org)), and the generic systemd tool for this,
   `kernel-install`, will build *a* valid UKI without error — just not the one Limine
   actually reads. `limine-mkinitcpio` (from the `limine-mkinitcpio-hook` package) is
   Omarchy's own tool, and the one actually wired into what Limine boots.

5. **Verify:**
   ```bash
   cat /sys/module/ttm/parameters/pages_limit      # expect 25165824
   sudo cat /sys/module/amdgpu/parameters/gttsize  # expect 98304
   llama-server --list-devices                     # expect ~98.8GB total, ~98.1GB free
   ```
   The small gap between the requested 96GB and the reported ~98.8GB is the 512MB BIOS
   reservation added on top of the GTT pool.

## Also worth knowing

- Backend: Vulkan (`ggml-vulkan`), not ROCm. Model in active use:
  `unsloth/Qwen3-Coder-Next-GGUF:Q5_K_M` (~53GB); `gpt-oss-120b` (MXFP4, ~59GB) is a
  fallback if the chat template misbehaves.
- `/dev/dri/renderD128` (the Vulkan compute node) is world-read/write by default on this
  device, so no `render`/`video` group changes were needed. Check this on another device
  before assuming the same.
- This device's router systemd unit (see [`setup/hosting-setup.md`](../setup/hosting-setup.md))
  uses `Environment=HF_HOME=/mnt/models/hf-cache`, `User=jaime`, and `--models-dir
  /home/jaime/models` — a dedicated second drive, per that doc's dedicated-drive path.
- Model-tunable settings (`--jinja`, GPU offload, context size, and any per-model
  overrides) live in [`../models/framework-desktop/models.ini`](../models/framework-desktop/models.ini),
  not on the command line — see [`../models/config.md`](../models/config.md) for why.
  [`../models/framework-desktop/install.sh`](../models/framework-desktop/install.sh)
  symlinks it into `/etc/llama-router/models.ini`; `restart-router.sh` restarts the
  service after a change.
- Package versions current as of this setup (September 2026): `llama-cpp` 0.4.0-1,
  `ggml-vulkan` 0.23.0-2, `amd-debug-tools` 0.2.21-1, `tailscale` 1.102.3-1.
