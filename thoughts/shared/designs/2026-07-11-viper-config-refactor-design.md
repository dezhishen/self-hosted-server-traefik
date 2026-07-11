date: 2026-07-11
topic: "Viper Config + Cross-Platform Refactoring"
status: validated

## Problem Statement

The project has three `os/exec` dependencies blocking Windows compatibility and creating fragility:
1. **Config Loader** (`backend/config/loader.go`) — reads/writes YAML directly with `os.ReadFile`/`os.WriteFile`/`yaml.Marshal` instead of using viper
2. **Subscription Manager** (`backend/subscription/manager.go`) — calls `exec.Command("git", "clone", ...)` to sync templates, requires Git to be installed
3. **Podman Adapter** (`backend/adapter/podman/runtime.go`) — every method shells out to `exec.Command("podman", ...)`, requires Podman CLI
4. **Endpoint Factory** (`backend/endpoint/factory.go`) — uses `exec.LookPath("docker")`/`exec.LookPath("podman")` for engine detection

All four block cross-platform builds (Windows/Linux/macOS).

## Constraints

- `contracts.AppConfig` struct and dual-file format (`system.yaml` + `endpoints.yaml` under `config/` subdirectory) must remain unchanged
- All config reads/writes must go through viper — no direct `os.ReadFile`/`yaml.Unmarshal`/`yaml.Marshal` for config files
- Docker adapter (`backend/adapter/docker/`) must stay untouched — already uses moby SDK, no `exec.Command` calls
- `backend/service/loader.go` loads YAML service definition files — these are NOT config files and are fine to keep as-is (they're read-only templates, not config)
- `backend/subscription/store.go` uses a JSON file for subscription metadata — this is fine, it's a data store not a config file

## Approach

We split the work into 4 independent phases that can be executed in parallel:

### Phase 1: Config Loader → Viper
Replace `backend/config/loader.go` entirely. The new implementation:
- Uses a single viper instance per directory, with `SetConfigName("system")` + `SetConfigName("endpoints")` to read/write both files
- Keeps the same `contracts.AppConfigLoader` interface so `core/config.go` needs zero changes
- Supports the same migration path from old single-file to new directory format
- Uses `viper.ReadInConfig()` for reads, `viper.WriteConfig()` or manual `viper.MarshalWriter()` for writes
- Removes `gopkg.in/yaml.v3` dependency from config package (still needed for service definitions)

### Phase 2: Subscription git clone → HTTP tarball
Replace `exec.Command("git", "clone", ...)` in `subscription/manager.go`:
- Parse the GitHub URL to extract owner/repo
- Download the default branch as a tarball (`https://api.github.com/repos/{owner}/{repo}/zipball`)
- Extract to target directory using `archive/zip` + `path/filepath` (pure Go, no external deps)
- Falls back to git clone ONLY if the URL is not a GitHub URL (generic git repos)

### Phase 3: Podman Adapter → moby SDK via Docker-compatible socket
Rewrite `backend/adapter/podman/runtime.go`:
- Remove all `exec.Command` calls
- Import and reuse `backend/adapter/docker/runtime.go`'s moby SDK approach
- Connect to Podman's Docker-compatible socket (`unix:///run/podman/podman.sock` on Linux, or the configured endpoint)
- Share the same moby SDK `client.Client` — Podman v4+ implements the Docker API
- The Podman runtime becomes a thin wrapper around docker.Runtime, just with different socket discovery

### Phase 4: Endpoint Factory → socket-based detection
Replace `exec.LookPath("docker")`/`exec.LookPath("podman")`:
- Try connecting to Docker socket first (`/var/run/docker.sock`)
- If that fails, try Podman socket (`/run/podman/podman.sock`)
- If both fail, return error
- This is more reliable than PATH lookup anyway — the binary might be installed but daemon not running

## Components Affected

| File | Change | Risk |
|------|--------|------|
| `backend/config/loader.go` | Full rewrite with viper | Medium — interface unchanged, behavior identical |
| `backend/subscription/manager.go` | Replace Sync() git clone with HTTP tarball | Medium — only affects Sync method |
| `backend/adapter/podman/runtime.go` | Full rewrite using moby SDK | High — large file, but behavioral contract identical |
| `backend/endpoint/factory.go` | Replace LookPath with socket connect | Low — small change |
| `cli/main.go` | `passwdCmd` and `startBackend` still use os/exec | Low — these are CLI bootstrap, not cross-platform critical (user-side commands) |
| `backend/core/config.go` | `SaveEndpoints`/`SaveSystem`/`loadSystemFromDisk` use direct YAML | Medium — these need migration to viper too |
| `backend/go.mod` | Add `spf13/viper` dep, potentially remove `gopkg.in/yaml.v3` | Low |

## Data Flow

### Config Load (new flow)
```
cli/main.go → AppConfigLoader.Load(path)
  → viper.AddConfigPath(path/config)
  → viper.SetConfigName("system") + ReadInConfig
  → viper.SetConfigName("endpoints") + ReadInConfig
  → marshal viper state into contracts.AppConfig
  → return *AppConfig
```

### Config Save (new flow)
```
AppConfigLoader.Save(cfg, path)
  → viper.Set("base_data_dir", cfg.BaseDataDir)
  → viper.SetConfigName("system") + WriteConfig
  → viper.Set("endpoints", cfg.Endpoints)
  → viper.SetConfigName("endpoints") + WriteConfig
```

### Subscription Sync (new flow)
```
Manager.Sync(name)
  → parse URL → if GitHub: HTTP GET zipball → archive/zip extract
  → else: exec.Command("git", "clone") [kept as fallback for non-GitHub]
```

### Podman Runtime (new flow)
```
Podman NewRuntime(cfg)
  → determine socket path
  → moby client.NewClientWithOpts(client.WithHost("unix://"+socketPath), ...)
  → all methods delegate to docker SDK calls
```

## Error Handling

- Viper file not found: catch `os.ErrNotExist` and return nil config (same as current behavior for first-run init)
- Tarball download failure: return wrapped error with URL and HTTP status
- Podman socket not available: return clear error "Podman socket not found at ..."
- All errors preserve the existing error contract — callers check `os.ErrNotExist` for first-run detection

## Testing Strategy

- **Phase 1**: Unit test the new viper-based loader — write temp dir, create system.yaml + endpoints.yaml, load, verify structs match. Test save + reload round-trip. Test migration from old single-file format.
- **Phase 2**: Unit test tarball download with a mock HTTP server. Test extraction logic with a known zip archive.
- **Phase 3**: Integration test against a running Podman socket (if available). Unit test with a mock moby client.
- **Phase 4**: Unit test socket detection logic — test with mock listener on random unix socket.

## Open Questions

- Should we keep `gopkg.in/yaml.v3` in go.mod for service definitions (`backend/service/loader.go`)? Yes — service YAML files are not config files, they're read-only template data.
- For non-GitHub git repos in subscription URLs, should we add a pure-Go git library? No — YAGNI. Just keep the `exec.Command` fallback for non-GitHub URLs. Users of private/self-hosted git repos likely have git installed.
