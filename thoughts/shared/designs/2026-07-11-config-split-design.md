---
date: 2026-07-11
topic: "Config Split — system.yaml + endpoints.yaml"
status: validated
---

## Problem Statement

The single-file config (`config.yaml`) bundles system settings (auth, base_data_dir) with frequently-edited endpoint configs under one `PUT /api/config` endpoint. Because `AuthConfig.PasswordHash` has `json:"-"`, the frontend never sends it — every Settings save wipes the password hash to empty string.

This is the root cause of the "endpoint没法保存" bug.

## Constraints

- `--config` / `-c` CLI parameter points to a **directory**, not a file
- Backward compatible: existing single-file configs auto-migrate on first launch
- Frontend API contract unchanged: `GET/PUT /api/config` returns/accepts same JSON shape
- Existing E2E tests must continue to pass
- `AuthConfig.PasswordHash` must never be writable via PUT /api/config

## Approach

Split the monolithic config into two files within a config **directory**:

```
<config-dir>/
├── system.yaml       # base_data_dir, auth (username + password_hash)
└── endpoints.yaml    # endpoints map only
```

`--config <dir>` points to the directory. On first launch with an old single-file config, auto-migrate by reading the old file, writing both new files, and renaming the old one to `.migrated`.

## Architecture

**New types in `contracts/config.go`:**

```go
type SystemConfig struct {
    BaseDataDir string      `yaml:"base_data_dir,omitempty" json:"base_data_dir,omitempty"`
    Auth        *AuthConfig `yaml:"auth,omitempty" json:"auth,omitempty"`
}

type EndpointCollection struct {
    Endpoints map[string]*EndpointConfig `yaml:"endpoints" json:"endpoints"`
}
```

`AppConfig` is preserved as the merged view for backward compatibility.

## Components

### Loader (`backend/config/loader.go`)

- **`Load(path)`** — detects if path is file or directory. If directory: reads `system.yaml` + `endpoints.yaml`. If file: reads old format, auto-migrates to directory.
- **`Save(cfg, dirPath)`** — writes `SystemConfig` to `system.yaml` + `EndpointCollection` to `endpoints.yaml`.
- **`DefaultPath()`** — returns `~/.config/selfhosted/` (directory) instead of `~/.config/selfhosted/config.yaml`.

### ConfigManager (`backend/core/config.go`)

- **`SaveEndpoints(eps)`** — writes ONLY `endpoints.yaml`, never touches `system.yaml`
- **`SaveSystem(system)`** — writes ONLY `system.yaml`
- **`SavePut(cfg)`** — safe handler for PUT /api/config: overwrites endpoints, preserves password_hash/base_data_dir, applies username if non-empty

### Server Handler (`backend/internal/server/server.go`)

PUT /api/config changed to call `ConfigManager.SavePut()` instead of `ConfigManager.Save()`. Only updates endpoints on disk. Merges system fields in-memory only.

## Data Flow

### Load Flow
```
ConfigManager.LoadOrInit()
  → Loader.Load(dirPath)
    → stat(dirPath)
    → if directory: read system.yaml → SystemConfig
                    read endpoints.yaml → EndpointCollection
                    merge into AppConfig
    → if file: read old file → AppConfig
               auto-migrate: create dir, write both files, rename old
    → return *AppConfig
```

### Save Flow (PUT /api/config)
```
Server.handleConfig(PUT)
  → json.Decode(r.Body) → incoming AppConfig
  → ConfigManager.SavePut(&incoming)
    → Load existing system from disk (to get password_hash)
    → Build merged SystemConfig:
        BaseDataDir = existing.BaseDataDir (never overwritten)
        Auth.Username = incoming.Auth.Username ?? existing.Auth.Username
        Auth.PasswordHash = existing.Auth.PasswordHash (always preserved)
    → SaveEndpoints(incoming.Endpoints)   // writes endpoints.yaml
    → SaveSystem(mergedSystem)            // writes system.yaml (only if auth changed)
  → Update s.app.Config in-memory
```

### Migration Flow
```
Loader.Load(oldFilePath)
  → os.Stat → it's a file (old format)
  → Read file → AppConfig
  → Create <oldFilePath>.d/ directory
  → Write system.yaml (from AppConfig.BaseDataDir + Auth)
  → Write endpoints.yaml (from AppConfig.Endpoints)
  → Rename old file to <oldFilePath>.migrated
  → Log migration notice
  → Change ConfigManager.path to new directory
  → Return AppConfig
```

## Error Handling

- **Missing system.yaml on first load:** Create with defaults (empty auth)
- **Missing endpoints.yaml:** Empty endpoints map, log info-level warning
- **Corrupt YAML in either file:** Fail-fast with parse error
- **Write failure during save:** Return HTTP 500, in-memory config unchanged
- **Migration failure (can't create dir):** Log error, continue using old file format (degraded mode)
- **Partial write:** system.yaml written first, then endpoints.yaml. If endpoints fails, system is consistent but endpoints are stale. Rare in practice (single-threaded HTTP).

## Testing Strategy

| Test Type | Coverage |
|-----------|----------|
| Unit | Loader: dir format, old format, migration, missing files |
| Unit | ConfigManager: SavePut preserves password_hash, applies username, never writes base_data_dir |
| Unit | Server: PUT handler merge logic |
| Integration | Full flow: old config → migration → PUT → verify file contents |
| E2E | All 30 existing tests must pass unchanged |
| Regression | Specifically: set password, PUT endpoints, verify password_hash on disk is intact |

## Open Questions

1. **Should `SavePut` write system.yaml at all, or only endpoints.yaml?** Current design: only endpoints.yaml on PUT. system.yaml is written only when auth explicitly changes (via `passwd` CLI or future auth API). This gives the strongest guarantee against accidental password_hash wipe. Trade-off: username changes via Settings page won't persist until we add a dedicated auth UI. Acceptable for now — username editing is low-frequency.

2. **Docker migration docs:** Need to update README to show `-v ./config/:/config` (directory mount) instead of `-v ./config.yaml:/config.yaml` (file mount). Old file mounts still work (auto-migration on first load) but the sidecar endpoints.yaml won't persist between container restarts.
