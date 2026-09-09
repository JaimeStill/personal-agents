# Networking

Previous: [Hosting setup](hosting-setup.md) · Next: [The Pi agent harness](pi-harness.md)

This doc covers what Tailscale needs beyond both machines simply being joined to the same
tailnet: exposing the host's router to the remote, and enabling remote terminal access.

## Prerequisites

Both host and remote are already joined to the same tailnet, with MagicDNS enabled (each
device resolves as `<hostname>.<tailnet-name>.ts.net`). On Omarchy, this comes from
running the Tailscale service install (`omarchy install service tailscale`), which also
sets the current user as the Tailscale operator, letting Tailscale commands run without
`sudo`.

## Reaching the router

A default personal tailnet's access rules already permit full connectivity between a
user's own devices. As long as the router (see [Hosting setup](hosting-setup.md)) binds to
the host's tailnet interface, the remote can already reach it by hostname:

```bash
curl http://<host-tailnet-name>:8080/health
```

No access-control edit is needed for this. If it doesn't work, check that the router is
actually bound to the tailnet IP (not `127.0.0.1`) and that MagicDNS is resolving the
name (`tailscale status` shows a `DNSName` for each device).

Binding the router to the tailnet interface, rather than `0.0.0.0`, is deliberate: it
keeps the router unreachable from any other network the host happens to be on (a home
LAN, for instance), without needing a local firewall rule to enforce it. Tailscale's own
device authentication is the access boundary.

## Remote terminal access

[Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh) replaces a separately
configured OpenSSH server and manual key distribution with authentication against the
tailnet identity. It's enabled per machine, not per tailnet, so run this on any machine
you want to SSH *into*:

```bash
sudo tailscale set --ssh
```

A default personal tailnet's access policy already permits SSH between a user's own
devices, in **check** mode: the first connection in a while prompts a browser
re-authentication. If those prompts get old, the tailnet's access policy (in the
[admin console](https://login.tailscale.com/admin/acls)) can change that rule's action
from `check` to `accept` for unattended access. This is the one piece of setup that has
to happen from the admin console, not the CLI.

Once enabled on a machine, connect to it from anywhere else on the tailnet:

```bash
ssh <hostname>
```

A few things behave differently from a plain OpenSSH server: only port 22 is intercepted
(no custom ports), port forwarding (`-L`/`-R`) needs a shell or command opened on the
connection first, and restarting `tailscaled` on either end drops active sessions.

Remote administration itself, once this is set up, is covered in
[Remote administration](remote-admin.md).

---
Previous: [Hosting setup](hosting-setup.md) · Next: [The Pi agent harness](pi-harness.md)
