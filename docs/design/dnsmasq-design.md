# dnsmasq Design — LAN-wide DNS for Floci

## 1. Purpose

Floci embeds `FLOCI_HOSTNAME` (`tianlu-floci`) into every URL it generates — SQS queue URLs, S3 pre-signed URLs, SNS subscription endpoints, Lambda callback URLs. For a client to use these URLs, the hostname `tianlu-floci` must resolve to the server's IP address.

On the server itself, `/etc/hosts` or the Podman network DNS handles this. But for **LAN clients** — developer laptops, CI runners, other machines on the network — there is no built-in resolution. Without dnsmasq, every LAN client needs a manual `/etc/hosts` entry:

```
10.0.x.x  tianlu-floci
```

This does not scale. Every new client needs the entry, and if the server IP changes, every entry must be updated.

dnsmasq solves this by running a lightweight DNS server on the Floci host that responds to queries for `tianlu-floci` (and optionally `*.floci`) with the server's LAN IP. LAN clients configure the server as their DNS resolver (or the router forwards queries for `.floci` to it), and resolution is automatic.

## 2. Why not just use the IP address?

Floci's generated URLs embed the hostname, not the IP. When a client receives an SQS queue URL like `https://tianlu-floci:4566/000000000000/my-queue`, it must resolve `tianlu-floci` to connect. There is no way to configure Floci to emit IP-based URLs without changing `FLOCI_HOSTNAME` to the raw IP — which breaks if the IP changes and is invalid for Podman container DNS (IPs are not valid DNS names for container networking).

## 3. What dnsmasq does

dnsmasq provides:

1. **Local DNS resolution** — maps `tianlu-floci` → server LAN IP for any client that uses it as a resolver.
2. **Wildcard domain support** — can map `*.floci` → server IP, so future services (e.g. `s3.tianlu-floci`, `lambda.tianlu-floci`) resolve automatically without individual entries.
3. **DHCP integration (optional)** — can advertise the DNS server to DHCP clients so they automatically use it. This requires dnsmasq to also run as the DHCP server, which may conflict with an existing router/DHCP server. Not recommended unless the Floci host is also the network's DHCP server.
4. **Cache** — caches upstream DNS responses, reducing latency for non-Floci queries.

## 4. How it works

```
┌──────────────┐        DNS query: "tianlu-floci?"         ┌──────────────┐
│  LAN client  │ ─────────────────────────────────────────▶│  dnsmasq on  │
│  (laptop)    │                                             │  Floci host  │
│              │◀───────────────────────────────────────── │  10.0.x.x │
│              │        Response: "10.0.x.x"             └──────────────┘
└──────────────┘                                                  │
                                                                  │ upstream
                                                                  ▼
                                                          ┌──────────────┐
                                                          │  Router /    │
                                                          │  ISP DNS     │
                                                          └──────────────┘
```

1. A LAN client queries `tianlu-floci`.
2. The query reaches dnsmasq (either because the client uses the Floci host as its DNS server, or because the router forwards `.floci` queries to it).
3. dnsmasq matches the `address=/tianlu-floci/10.0.x.x` rule and responds with the server's LAN IP.
4. For any other query (e.g. `google.com`), dnsmasq forwards to the upstream resolver (router or ISP DNS) and caches the response.

## 5. Configuration

### 5.1 dnsmasq config

A minimal `/etc/dnsmasq.d/floci` configuration:

```ini
# Map tianlu-floci to the server's LAN IP
address=/tianlu-floci/10.0.x.x

# Optional: wildcard for future *.tianlu-floci subdomains
# address=/.tianlu-floci/10.0.x.x

# Upstream DNS (auto-detect from /etc/resolv.conf or resolvectl)
server=10.0.0.1

# Only listen on the LAN interface (auto-detect via ip route)
interface=enp3s0
bind-interfaces

# Don't read /etc/hosts (avoid leaking host entries)
no-hosts

# Don't forward queries without a domain (reduces upstream leaks)
domain-needed

# Don't forward reverse lookups for private IPs
bogus-priv

# Cache size
cache-size=1000
```

The server IP and LAN interface are auto-detected at setup time:
- IP: `hostname -I` filtered to exclude container bridges, Tailscale CGNAT (100.64.0.0/10), and link-local. Prefer RFC1918 on the default-route interface.
- Interface: `ip route show default | awk '{print $5; exit}'` — the interface used for the default route.

### 5.2 Port conflict with systemd-resolved

Ubuntu 26.04 ships with `systemd-resolved` which binds port 53 on `127.0.0.53` **and** on `0.0.0.0:53` on all interfaces by default (`DNSStubListener=yes`). dnsmasq cannot bind port 53 on the LAN interface while systemd-resolved holds it.

**Required fix:** Disable systemd-resolved's stub listener before starting dnsmasq:

```sh
# Edit /etc/systemd/resolved.conf
[Resolve]
DNSStubListener=no

# Restart systemd-resolved to free port 53
systemctl restart systemd-resolved
```

`bind-interfaces` + `interface=<lan>` alone does **not** work — systemd-resolved already holds the port on that interface. The design must set `DNSStubListener=no` in `resolved.conf` as a prerequisite step.

After disabling the stub listener, configure `/etc/resolv.conf` to point at dnsmasq (or the upstream directly) so the host itself can still resolve names.

### 5.3 Firewall

dnsmasq listens on both UDP and TCP port 53. The firewall must allow both:

```sh
ufw allow from 10.0.0.0/8 to any port 53 proto udp
ufw allow from 10.0.0.0/8 to any port 53 proto tcp
ufw allow from 172.16.0.0/12 to any port 53 proto udp
ufw allow from 172.16.0.0/12 to any port 53 proto tcp
ufw allow from 192.168.0.0/16 to any port 53 proto udp
ufw allow from 192.168.0.0/16 to any port 53 proto tcp
```

### 5.4 Client configuration

LAN clients must use the Floci host as their DNS resolver. Options:

- **Manual:** Set the Floci host IP as the DNS server on each client.
- **Router DHCP:** Configure the router to hand out the Floci host IP as the DNS server (or as a secondary DNS after the router itself).
- **Router forward rule:** Configure the router to forward queries for `.floci` to the Floci host. The router remains the primary DNS; dnsmasq only handles `.floci` queries.

## 6. Gotchas

### 6.1 systemd-resolved port 53 conflict

If dnsmasq fails to start with "address already in use" on port 53, `systemd-resolved` is holding it on `0.0.0.0:53`. `bind-interfaces` does not help. The fix is `DNSStubListener=no` in `/etc/systemd/resolved.conf` followed by `systemctl restart systemd-resolved`. See section 5.2.

### 6.2 Dynamic IP addresses

If the server's LAN IP changes (DHCP lease renewal, network change), dnsmasq's `address=` entry becomes stale. The script should auto-detect the current IP and warn if it differs from the configured value. For a stable setup, assign a static IP to the server or configure a DHCP reservation.

### 6.3 Floci certificate SANs

Floci's self-signed TLS certificate includes `FLOCI_HOSTNAME` in its SANs. `tianlu-floci` is included. If dnsmasq maps a different name (e.g. `floci.lan`), clients connecting via that name will get a TLS hostname mismatch. The dnsmasq `address=` entry must match `FLOCI_HOSTNAME`.

### 6.4 Not a prerequisite for Floci

dnsmasq is not required for Floci to start or function on localhost. It only affects LAN client hostname resolution. The `setup-floci.sh` script does not depend on dnsmasq being installed.

### 6.5 Podman container DNS is separate

dnsmasq resolves hostnames for LAN clients. Podman containers use the Podman network's built-in DNS resolver, not dnsmasq. The `tianlu-floci` hostname resolves inside the Podman network because it matches the container name (set via `--name tianlu-floci`). dnsmasq does not need to be reachable from inside containers.

### 6.6 Future Tailscale integration

If Tailscale is installed in the future, Tailscale MagicDNS can handle `tianlu.uk` resolution. dnsmasq and Tailscale can coexist — dnsmasq handles `.tianlu-floci` locally, Tailscale handles `tianlu.uk` via MagicDNS. Ensure dnsmasq does not forward `.ts.net` or `tianlu.uk` queries upstream if Tailscale is managing them.

### 6.7 TCP DNS

dnsmasq listens on both UDP and TCP port 53. TCP is used for large DNS responses (>512 bytes), DNSSEC, and zone transfers. The firewall must allow both protocols (see section 5.3).

### 6.8 `no-hosts` side effect

Setting `no-hosts` means dnsmasq will not serve entries from `/etc/hosts`. If the server has other services reachable by hostname via `/etc/hosts`, LAN clients won't resolve them through dnsmasq. Only the explicit `address=` entries will be served.

### 6.9 Open resolver risk

Without `domain-needed` and `bogus-priv`, dnsmasq acts as an open recursive resolver for any client that can reach port 53. This can leak internal network topology upstream and enable DNS amplification. The config includes both options to mitigate this. For additional security, restrict port 53 to the specific LAN subnet rather than all RFC1918 ranges.

## 7. Why this is helpful for Floci

| Without dnsmasq | With dnsmasq |
|---|---|
| Each LAN client needs a manual `/etc/hosts` entry | Automatic resolution for all LAN clients |
| IP changes require updating every client | Update one dnsmasq config (or auto-detect) |
| No wildcard support — each subdomain needs its own entry | `*.floci` wildcard maps all future subdomains |
| Clients must use raw IP in `--endpoint-url` | Clients use `https://tianlu-floci:4566` naturally |
| Pre-signed URLs with hostname fail on LAN clients | Pre-signed URLs work everywhere on the LAN |

## 8. Relationship to setup-floci.sh

`setup-dnsmasq.sh` is a separate, independent script. It runs after `setup-floci.sh` has completed (so the server IP and hostname are known). It is not a prerequisite — `setup-floci.sh` does not check for or depend on dnsmasq.

The script should:

1. Install `dnsmasq` via apt (idempotent — check `command -v dnsmasq`).
2. Auto-detect the server's LAN IP from `hostname -I`.
3. Write `/etc/dnsmasq.d/floci` with the `address=/tianlu-floci/<IP>` mapping.
4. Configure dnsmasq to bind only on the LAN interface (avoid systemd-resolved conflict).
5. Enable and start the `dnsmasq` system service.
6. Open UFW port 53/udp for RFC1918 subnets.
7. Print instructions for configuring client DNS (manual, router DHCP, or router forward rule).