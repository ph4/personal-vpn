# nginx_certbot

Sets up Nginx with Let's Encrypt certificates per site, using shared tasks.

## Structure

- `tasks/main.yml` — one-time host setup (packages, nginx enable, LE webroot dir, renewal hook/cron)
- `tasks/site.yml` — per-site operations (cert check, nginx config deploy, certbot certonly)
- `handlers/main.yml` — `reload nginx` handler

## Usage

Run `nginx_certbot` once per host, then call `site.yml` from each app role:

```yaml
# playbook
- hosts: main
  roles:
    - nginx_certbot    # once per host
    - myapp            # app role, includes site.yml internally
```

Each app role defines site vars in its own `defaults/main.yml` and invokes the shared task:

```yaml
# roles/myapp/defaults/main.yml
site_domain: "myapp.example.com"
site_www: true
site_backend: "http://localhost:3000"
site_trusted_proxies: []   # optional

# roles/myapp/tasks/main.yml
- name: Setup nginx
  include_role:
    name: nginx_certbot
    tasks_from: site.yml
```

## Variables

### Global (defaults)

| Variable | Default | Description |
|---|---|---|
| `certbot_email` | `admin@example.com` | Email for Let's Encrypt account |
| `certbot_auto_renew` | `true` | Enable auto-renewal |
| `certbot_renew_hour` | `3` | Cron hour for renewal (only if systemd timer absent) |
| `certbot_renew_minute` | `30` | Cron minute for renewal |

### Per-site (defined in app role defaults)

| Variable | Required | Description |
|---|---|---|
| `site_domain` | yes | Primary domain |
| `site_www` | no | Also request cert for `www.<domain>` |
| `site_root` | no | Document root for static sites (default: `/var/www/html`) |
| `site_backend` | no | Proxy pass target (empty = serve static files) |
| `site_trusted_proxies` | no | List of trusted proxy IPs for `set_real_ip_from`. Defaults to `['127.0.0.1']` in the template if unset. Set to `[]` to disable real IP resolution entirely. |

## Renewal

On RHEL 8+ the `certbot` dnf package ships its own `certbot-renew.timer`. The role detects this and skips the cron job. A deploy hook at `/etc/letsencrypt/renewal-hooks/deploy/nginx-reload` handles nginx reload after renewal regardless of which scheduler triggers it.
