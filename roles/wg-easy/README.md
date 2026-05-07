# wg-easy

Deploys [wg-easy](https://github.com/wg-easy/wg-easy) (WireGuard web UI) as a Docker container behind nginx with Let's Encrypt.

## Structure

- `tasks/main.yml` — pre-flight checks (Docker, optional amneziawg module), nginx site setup, compose directory, template deploy, compose up
- `handlers/main.yml` — `docker-compose restart` triggered on template changes
- `templates/docker-compose.yml.j2` — Docker Compose file with dual-stack IPv4/IPv6 networking
- `defaults/main.yml` — default variables (site config, Docker network, client IP ranges, ports)

## Usage

Requires the `docker` role and `nginx_certbot` role to have run first on the host:

```yaml
- hosts: main
  roles:
    - nginx_certbot
    - docker
    - wg-easy
```

The role defines site vars for nginx_certbot in its own `defaults/main.yml` and includes `nginx_certbot/tasks/site.yml` internally.

## Variables

| Variable | Default | Description |
|---|---|---|
| `site_domain` | `wgb.hosts.name` | Domain for the wg-easy web UI |
| `site_backend` | `http://127.0.0.1:{{ wg_easy_host_port_tcp }}` | Proxy pass target (derived from host port) |
| `compose_dir` | `/etc/docker/containers/wg-easy` | Compose project directory |
| `wg_easy_image` | `ghcr.io/wg-easy/wg-easy:15.3.0-beta.2` | Container image |
| `wg_easy_use_awg` | `false` | Use amneziawg kernel module instead of wireguard |
| `wg_easy_ipv4_subnet` | `10.42.0.0/24` | Docker bridge IPv4 subnet |
| `wg_easy_ipv6_subnet` | `fd:cafe:42::/64` | Docker bridge IPv6 subnet |
| `wg_easy_client_ipv4_cidr` | `10.42.1.0/24` | WireGuard client IPv4 range |
| `wg_easy_client_ipv6_cidr` | `fd:cafe:42::1:0/112` | WireGuard client IPv6 range |
| `wg_easy_ipv4` | `10.42.0.2` | Container IPv4 address (update if subnet changes) |
| `wg_easy_ipv6` | `fd:cafe:42::2` | Container IPv6 address (update if subnet changes) |
| `wg_easy_container_port_udp` | `51820` | Container UDP port for WireGuard |
| `wg_easy_container_port_tcp` | `51821` | Container TCP port for web UI |
| `wg_easy_host_port_udp` | `{{ wg_easy_container_port_udp }}` | Host UDP port for WireGuard |
| `wg_easy_host_port_tcp` | `{{ wg_easy_container_port_tcp }}` | Host TCP port for web UI |

Host ports derive from their container port counterparts.

## Notes

- `INSECURE=true` is set, exposing the admin UI without auth. Access control relies on nginx or upstream configuration.

- `site_trusted_proxies` is deliberately left unset, so the nginx template's inner default of `['127.0.0.1']` applies. This gives nginx a `set_real_ip_from 127.0.0.1` directive, resolving the real client IP from `X-Forwarded-For`.

- If `wg_easy_ipv4_subnet` overlaps with `wg_easy_client_ipv4_cidr`, Docker's POSTROUTING MASQUERADE rule (`-s <subnet> -j MASQUERADE`) will SNAT WireGuard client traffic leaving the host. Route the client subnet appropriately or keep the subnets disjoint.
