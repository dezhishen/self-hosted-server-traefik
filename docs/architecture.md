# Architecture

## Module Dependency

```mermaid
graph TD
    subgraph "Go Modules"
        C[contracts] -->|interfaces only| B[backend]
        C -->|interfaces only| S[sdk]
        B -->|implementations| S
        S -->|high-level API| CLI[cli]
    end

    subgraph "Frontend"
        FE[frontend] -->|build → embed| CLI
    end

    subgraph "External"
        DOCKER[docker/podman]
        FS[~/.args/]
        YAML[templates/*.yaml]
        REMOTE[remote registries]
    end

    B --> DOCKER
    B --> FS
    B --> YAML
    S --> REMOTE
```

## Directory Layout

```
self-hosted-server-traefik/
├── contracts/          # Go module: pure interfaces (no deps)
│   ├── runtime.go      # ContainerRuntime, RuntimeFactory
│   ├── config.go       # ConfigStore, AppConfig, RemoteConfig
│   ├── param.go        # ParamDef, ParamStore, typed params
│   ├── service.go      # ServiceDefinition, ServiceManager
│   ├── template.go     # TemplateEngine, ServiceLoader
│   ├── subscription.go # Subscription, SubscriptionManager
│   └── label.go        # Managed label constants
│
├── backend/            # Go module: implementations
│   ├── adapter/        # Docker / Podman runtime adapters
│   ├── config/         # YAML config file loader
│   ├── store/          # ~/.args/ backed ConfigStore
│   ├── template/       # Go template renderer
│   └── service/        # ServiceManager implementation
│
├── sdk/                # Go module: unified high-level API
│   ├── client.go       # Client struct, New(), lifecycle helpers
│   └── ...
│
├── cli/                # Go module: CLI entry point
│   ├── main.go         # CLI runner with -c/--host flags
│   ├── serve.go        # //go:embed web/dist
│   └── web/dist/       # Built frontend (embedded)
│
├── frontend/           # Vue 3 + Element Plus + Tailwind
│   ├── src/            # Source code
│   ├── e2e/            # Playwright E2E tests
│   └── vite.config.ts  # Build → cli/web/dist/
│
├── templates/          # YAML service definitions
│   └── services/       # ~65 built-in services
│
├── docker/             # Custom Docker image definitions
│   ├── opencode/
│   └── apache-utils/
│
├── build/              # Build & package artifacts
│   └── package/        # Dockerfiles for CLI / backend images
│
├── docs/               # Documentation
├── go.work             # Go workspace
└── Makefile
```

## Data Flow: `selfhosted install traefik`

```mermaid
sequenceDiagram
    participant User
    participant CLI as cli
    participant SDK as sdk.Client
    participant Backend as backend
    participant Runtime as ContainerRuntime
    participant FS as ~/.args/ + templates/

    User->>CLI: selfhosted -c cfg.yaml install traefik
    CLI->>CLI: parse flags → load config
    CLI->>SDK: New(ctx, Options{ConfigPath})
    SDK->>Backend: config.Loader.Load(cfg.yaml)
    Backend-->>SDK: AppConfig{Remotes, Subscriptions}
    SDK->>Backend: runtimeFactory.Create(remote.Connection)
    Backend-->>SDK: ContainerRuntime (docker/podman)
    SDK-->>CLI: *Client

    CLI->>SDK: Install("traefik", params)
    SDK->>Backend: serviceLoader.Load("traefik")
    Backend->>FS: templates/services/traefik.yaml
    FS-->>Backend: ServiceDefinition
    Backend->>Backend: renderConfig(def, params)
    Backend->>Backend: resolveParamStore(params)
    Backend->>Backend: runInit(def.Init)
    Backend->>Runtime: ContainerRun(renderedParams)
    Runtime-->>Backend: container started
    Backend-->>SDK: nil
    SDK-->>CLI: nil
    CLI-->>User: ✅ traefik installed
```

## Label Convention

All managed containers receive:

| Label | Value |
|---|---|
| `selfhosted.managed` | `true` |
| `selfhosted.service` | `<service-name>` |
| `selfhosted.version` | `<git-sha>` |
| `selfhosted.host` | `<remote-name>` |
| `selfhosted.engine` | `docker` / `podman` |

## Remote Connection

```mermaid
graph LR
    CLI -->|unix://| DOCKER[local Docker]
    CLI -->|tcp://host:2375| REMOTE[remote Docker API]
    CLI -->|ssh://user@host| SSH[SSH tunnel → remote socket]
```

## Subscription Sync

```mermaid
graph LR
    REGISTRY[remote registry] -->|fetch YAML| CLI
    CLI -->|write| TEMPLATES[templates/<name>/]
    ServiceLoader -->|scan| LOCAL[templates/services/]
    ServiceLoader -->|scan| SUB[templates/<name>/]
    LOCAL -->|merge| SDK
    SUB -->|merge| SDK
```
