# Usage

## Configuration

The config file is a YAML file (default `~/.config/selfhosted/config.yaml`,
customizable via `-c`). See [`selfhosted.example.yaml`](../selfhosted.example.yaml).

```yaml
base_data_dir: /var/lib/selfhosted     # logs, args, configs

auth:
  username: admin                       # web dashboard login
  password_hash: "$2a$10$..."          # set via `passwd` command

endpoints:                              # each = independent runtime
  default:
    name: default
    default: true
    connection:
      type: unix                        # unix | tcp | http | https | ssh
      endpoint: /var/run/docker.sock
      engine: auto                      # docker | podman | auto
      tls:                              # required for tcp/https with TLS
        enabled: true
        ca_cert: |                      # PEM content (optional, uses system CA if empty)
          -----BEGIN CERTIFICATE-----
          ...
        skip_verify: false

  myserver:
    name: myserver
    connection:
      type: https
      endpoint: docker.example.com:2376
      engine: docker
      tls:
        enabled: true

subscriptions:                          # community service template sync
  - name: community
    url: https://github.com/user/repo
    enabled: true
```

## CLI Commands

### Manage the password

```bash
selfhosted -c config.yaml passwd            # generates random password
selfhosted -c config.yaml passwd mypass123  # use specific password
```

### List available services

Shows all services from local `templates/services/` and synced subscriptions:

```bash
selfhosted -c config.yaml list
```

### Install a service

```bash
selfhosted -c config.yaml install traefik
selfhosted -c config.yaml install jellyfin --param jellyfin_port=8096
```

The command:
1. Loads the service YAML definition
2. Saves parameters to `~/.args/`
3. Pulls the container image
4. Creates network if needed
5. Runs the container with managed labels (`selfhosted.*`)
6. Executes post-install hooks

### Check service status

```bash
selfhosted -c config.yaml status jellyfin
```

### Uninstall a service

```bash
selfhosted -c config.yaml uninstall jellyfin
```

Stops and removes the container, preserves parameters.

### Web Dashboard

```bash
# Starts backend API + embedded frontend
selfhosted -c config.yaml serve

# Custom port (default :8080)
selfhosted -c config.yaml serve :3000
```

Dashboard features:
- **Dashboard** — runtime info, container overview, stat cards
- **Services** — browse, search, install, restart, uninstall, view logs
- **Subscriptions** — add/remove/sync community template sources
- **Settings** — view/edit config (endpoints, auth) from the browser

The dashboard selects endpoints via the sidebar dropdown. Each endpoint
is a separate runtime (local Docker, remote Docker, Podman VM, etc.).

### Manage subscriptions

Subscriptions sync community service templates from Git repositories:

```bash
selfhosted -c config.yaml sub add community https://github.com/user/repo
selfhosted -c config.yaml sub list
selfhosted -c config.yaml sub sync community
selfhosted -c config.yaml sub remove community
```

Synced templates appear under `templates/<name>/` and are merged with
local templates (`templates/services/`).

### Manage endpoints (remotes)

```bash
selfhosted -c config.yaml remote add myserver tcp://192.168.1.100:2376
selfhosted -c config.yaml remote list
selfhosted -c config.yaml remote remove myserver
```

## Service Templates

Service definitions are YAML files in `templates/services/`.

Each file describes:
```yaml
name: myapp
description: My application
category: Tools
image: myapp:latest
container:
  ports:
    - host_port: 8080
      container_port: 3000
  env:
    APP_PORT: "3000"
params:
  - name: app_port
    type: number
    default: 3000
    env_mapping:
      APP_PORT: "{{ .Value }}"
```

See [`templates/services/_schema.yaml`](../templates/services/_schema.yaml) for the full schema.

## Connection Types

| Type    | Purpose                     | TLS Config | Example                          |
|---------|-----------------------------|------------|----------------------------------|
| `unix`  | Local Docker socket         | No         | `/var/run/docker.sock`           |
| `tcp`   | Remote Docker (optional TLS)| Optional   | `192.168.1.100:2375`             |
| `http`  | Remote Docker (plain TCP)   | No         | `docker.example.com:2375`        |
| `https` | Remote Docker (TLS)         | Required   | `docker.example.com:2376`        |
| `ssh`   | Podman over SSH             | No         | `user@10.0.0.50`                 |

For `https` connections with public certificate authorities (e.g. Docker
Proxy services), leave CA cert fields empty — the system CA bundle is used.
For self-signed certs, paste PEM content into the CA Cert field.
