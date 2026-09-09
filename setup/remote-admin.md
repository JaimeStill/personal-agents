# Remote administration

Previous: [The Pi agent harness](pi-harness.md)

This doc covers managing the host from the remote day to day: terminal sessions, moving
files between the two, pushing updates, and recovering from a restart. It assumes
Tailscale SSH is already enabled on the host, per [Networking](networking.md).

## Terminal sessions

```bash
ssh <host-tailnet-name>
```

authenticates against the tailnet identity, no key or password involved. This is a
regular interactive shell on the host: run anything you'd run sitting at it directly.

## Moving files

Two tools cover different needs:

- **[Taildrop](https://tailscale.com/kb/1106/taildrop)** (`tailscale file cp`, or the GUI
  "Send file") for a one-off file or small batch. It's resumable but not meant for keeping
  a directory in sync.
- **`rsync`/`scp` over Tailscale SSH** for anything that needs to stay in sync, using the
  MagicDNS hostname the same as any other SSH target:

  ```bash
  rsync -avz ~/some-directory/ <host-tailnet-name>:~/some-directory/
  ```

  This repository is a reasonable example of something to keep synced this way between
  host and remote.

## Updates

Package updates, `pi` updates, and rebuilding llama.cpp all happen the same way over an
SSH session to the host as they would sitting at it: there's no separate remote-update
mechanism to learn. SSH in, run the update, done.

## Restart recovery

Because the router runs as an enabled systemd service (see
[Hosting setup](hosting-setup.md)), a reboot brings it back on its own:

```bash
ssh <host-tailnet-name> sudo reboot
```

**Only do this when you can be physically present to log back in afterward.** A host
with disk encryption or any other boot-time authentication won't come all the way back up
on its own — it'll sit waiting for input that has nowhere to arrive from over the network.
Rebooting a host you can't walk over to defeats the point of managing it remotely.

The standard health-check and recovery loop, run from the remote over SSH:

```bash
ssh <host-tailnet-name> systemctl status llama-router
ssh <host-tailnet-name> systemctl restart llama-router
ssh <host-tailnet-name> journalctl -u llama-router -n 50
```

If a `pi` session was mid-conversation when the host restarted, no special recovery is
needed on the remote's side beyond reopening `/llama` and reloading the model once the
host is back — session state on the remote is untouched by the host restarting.

## A quality-of-life addition worth making

With `pi` and SSH sessions both open to different machines over the course of a day, it's
easy to lose track of which terminal is actually connected to what. If your prompt is
managed by [Starship](https://starship.rs), its built-in `hostname` module with
`ssh_only = true` shows the hostname only inside an SSH session, invisible otherwise. Add a
module block like this to `starship.toml`, and add `$hostname` to the top-level `format`
string wherever it should render:

```toml
format = "$hostname[$directory$git_branch$git_status]($style)$character"

[hostname]
ssh_only = true
format = "[$hostname](bold red) "
```

This lives in your shell dotfiles, not this repository — it's a general terminal
preference, not something specific to this setup.

---
Previous: [The Pi agent harness](pi-harness.md)
