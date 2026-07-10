# Deployment

## Build from Source

### Prerequisites

- Go 1.24+
- Node.js 22+ (for frontend)
- Docker or Podman (for runtime testing)

### Build CLI (with embedded frontend)

```bash
make build
```

Produces `./bin/selfhosted`. The Vue frontend is compiled, hashed, and
embedded into the Go binary via `//go:embed`.

### Build backend only

```bash
make build-backend
```

Produces `./bin/selfhosted-backend`.

### Cross-compile

```bash
make build-linux-amd64
make build-linux-arm64
make build-linux-arm
make build-darwin-amd64
make build-darwin-arm64
```

Output in `build/release/`.

## Docker

### CLI image

```dockerfile
# build/package/cli.Dockerfile
# Multi-stage: node → go → alpine
docker build -t selfhosted/cli -f build/package/cli.Dockerfile .
```

Published on `ghcr.io/dezhishen/self-hosted-server-traefik/cli:latest`.

Run:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v $PWD/config.yaml:/config.yaml \
  ghcr.io/dezhishen/self-hosted-server-traefik/cli:latest \
  -c /config.yaml list
```

### Backend image

```dockerfile
# build/package/backend.Dockerfile
# Multi-stage: go → alpine
docker build -t selfhosted/backend -f build/package/backend.Dockerfile .
```

Published on `ghcr.io/dezhishen/self-hosted-server-traefik/backend:latest`.

Run:

```bash
docker run -d -p 18080:18080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $PWD/config.yaml:/config.yaml \
  ghcr.io/dezhishen/self-hosted-server-traefik/backend:latest \
  -c /config.yaml --addr :18080
```

## Development Setup

```bash
make dev
```

Starts:
- Backend on `:18080` (via `go run`)
- Frontend on `:5173` with hot-reload (via `npx vite`)
- Frontend proxies `/api/*` to backend

## Production Considerations

1. **Auth**: Always set a password via `passwd` before exposing the dashboard.
2. **TLS**: Run behind a reverse proxy (Traefik, nginx, Caddy) with TLS termination.
3. **Data dir**: Use a persistent volume for `base_data_dir` to preserve args and logs.
4. **Backend only**: For multi-user scenarios, run the backend separately and
   use a reverse proxy to expose the API with authentication.
5. **Monitoring**: Backend logs structured JSON to `base_data_dir/logs/`.

## Release Process

1. Tag the commit: `git tag v0.x.x`
2. Push tag: `git push origin v0.x.x`
3. GitHub Actions builds and releases:
   - Multi-arch binaries via GoReleaser
   - Docker images for CLI and backend
   - Published to GitHub Releases + GHCR

See [`.goreleaser.yaml`](../.goreleaser.yaml) and
[`.github/workflows/release.yml`](../.github/workflows/release.yml).
