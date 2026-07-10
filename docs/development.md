# Development

## Prerequisites

- Go 1.22+
- Node.js 20+
- Docker or Podman

## Quick Start

```bash
# Clone
git clone git@github.com:dezhishen/self-hosted-server-traefik.git
cd self-hosted-server-traefik

# Build CLI with embedded frontend
make build

# Run
./bin/selfhosted help
```

## Module Development

```bash
# Run all Go tests
make test-go

# Run frontend E2E tests
make test-e2e

# Lint
make lint

# Frontend dev server (hot-reload)
make dev-frontend

# CLI dev (serve dashboard)
make dev
```

## Adding a New Service

1. Create a YAML file in `templates/services/<name>.yaml`
2. Follow the schema in `templates/services/_schema.yaml`
3. Build and test:
   ```bash
   make build
   ./bin/selfhosted list  # should show your service
   ```

## Adding a New Parameter Type

1. Add the type constant in `contracts/param.go`
2. Add storage/handling in `backend/store/args.go`
3. Add rendering in `backend/template/engine.go`

## Project Commands

```bash
make build              # Build CLI (+ frontend)
make build-backend      # Build backend only
make test               # Run Go tests
make test-e2e           # Run Playwright E2E
make lint               # golangci-lint
make clean              # Clean artifacts
make dev                # Build + serve dashboard
```
