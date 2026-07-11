# Config Split Implementation Plan

## Group 1: Types + Loader (contracts + backend/config)

### Task 1.1: Add SystemConfig and EndpointCollection types
- **File:** `contracts/config.go`
- **Changes:**
  - Add `SystemConfig` struct with `BaseDataDir` + `Auth *AuthConfig` (yaml + json tags, omitempty)
  - Add `EndpointCollection` struct with `Endpoints map[string]*EndpointConfig` (yaml + json tags)
  - `AppConfig` stays as-is (merged view)
- **Verify:** `go build ./contracts/...` passes

### Task 1.2: Refactor Loader for directory-based config
- **File:** `backend/config/loader.go`
- **Changes:**
  - `Load(path string)`:
    - `os.Stat(path)` → if dir, call `loadDir(path)`; if file, call `loadFile(path)` then `migrateToDir(path, cfg)`
    - `loadDir(dir)`: read `dir/system.yaml` into `SystemConfig`, read `dir/endpoints.yaml` into `EndpointCollection`, merge into `AppConfig`
    - `loadFile(path)`: existing behavior (read single file, unmarshal into AppConfig)
    - `migrateToDir(oldPath, cfg)`: create `oldPath + ".d/"` dir, write `system.yaml` + `endpoints.yaml`, rename old file to `oldPath + ".migrated"`, update and return new dir path
  - `Save(cfg, dirPath)`:
    - Write `SystemConfig{BaseDataDir, Auth}` to `dirPath/system.yaml`
    - Write `EndpointCollection{Endpoints}` to `dirPath/endpoints.yaml`
  - `DefaultPath()`: return `filepath.Join(home, ".config", "selfhosted")` (directory, no filename)
- **Verify:** `go build ./backend/config/...` passes

### Task 1.3: Create migration helper
- **File:** `backend/config/loader.go`
- **Logic:**
  - `func (l *Loader) migrateToDir(oldPath string, cfg *AppConfig) (newDir string, err error)`
  - New dir = `oldPath + ".d"`
  - Create dir with MkdirAll
  - Write system.yaml and endpoints.yaml using existing Save logic
  - Rename oldPath to oldPath + ".migrated" via `os.Rename`
  - Log migration notice (fmt.Printf or log)
  - Return newDir
- **Verify:** Unit test: old file loaded, migration creates correct files

## Group 2: ConfigManager (backend/core)

### Task 2.1: Add SaveEndpoints, SaveSystem, SavePut methods
- **File:** `backend/core/config.go`
- **Changes:**
  - `SaveEndpoints(eps map[string]*EndpointConfig) error`:
    - Marshal only `EndpointCollection{Endpoints: eps}` to YAML
    - Write to `filepath.Join(m.path, "endpoints.yaml")`
  - `SaveSystem(system *SystemConfig) error`:
    - Marshal `system` to YAML
    - Write to `filepath.Join(m.path, "system.yaml")`
  - `SavePut(cfg *AppConfig) error`:
    - Load existing `system.yaml` from disk → `existingSystem`
    - Build merged: endpoints from cfg, BaseDataDir from existingSystem, Auth from existingSystem (preserve password_hash)
    - Apply cfg.Auth.Username if non-empty
    - Call `SaveEndpoints(cfg.Endpoints)`
    - If auth changed: call `SaveSystem(mergedSystem)`
    - Return nil
  - Keep existing `Save(cfg)` as-is (writes both files via loader)
- **Verify:** `go build ./backend/core/...` passes

### Task 2.2: Update LoadOrInit for directory path
- **File:** `backend/core/config.go`
- **Changes:**
  - In `LoadOrInit()`: `m.path` may be updated during migration (file→dir). Store the new path back.
  - After `m.loader.Load(m.path)`: if the loader returns a new path (post-migration), update `m.path`
- **Verify:** Load old config, confirm m.path changes to new directory

## Group 3: Server + CLI

### Task 3.1: Fix PUT /api/config handler
- **File:** `backend/internal/server/server.go`
- **Changes:**
  - In `handleConfig` PUT case:
    ```go
    var incoming contracts.AppConfig
    json.NewDecoder(r.Body).Decode(&incoming)
    if err := s.app.ConfigMgr.SavePut(&incoming); err != nil {
        jsonErr(w, 500, err.Error())
        return
    }
    // Update in-memory endpoints
    s.app.Config.Endpoints = incoming.Endpoints
    if incoming.Auth != nil && incoming.Auth.Username != "" {
        s.app.Config.Auth.Username = incoming.Auth.Username
    }
    jsonResp(w, map[string]string{"status": "ok"})
    ```
- **Verify:** `go build ./backend/...` passes

### Task 3.2: Update CLI passwd command
- **File:** `cli/main.go` (function `passwdCmd`)
- **Changes:**
  - If configPath is a directory: read `configPath/system.yaml` instead of `configPath` as file
  - Write back to `configPath/system.yaml`
  - Help text: `-c, --config <dir>` Config directory path
- **Verify:** `go build ./cli/...` passes

## Group 4: Dev Config + Tests

### Task 4.1: Migrate dev config to directory
- Convert `.selfhosted.dev.yaml` (single file) to `.selfhosted.dev/` (directory)
- Create `.selfhosted.dev/system.yaml` with base_data_dir + auth
- Create `.selfhosted.dev/endpoints.yaml` with default endpoint
- Update Makefile and any scripts that reference the config path
- **Verify:** `make build-backend && bin/selfhosted-backend -c .selfhosted.dev/ --addr :18080` starts

### Task 4.2: Write Loader tests
- **File:** `backend/config/loader_test.go` (new)
- **Tests:**
  - `TestLoadDirectory`: create temp dir with system.yaml + endpoints.yaml → load, verify merge
  - `TestLoadOldFile`: create temp old-format file → load, verify migration happened, verify dir created
  - `TestLoadEmptyDir`: empty dir → load, verify returns defaults
  - `TestSaveThenLoad`: save AppConfig → load back, verify round-trip
- **Verify:** `go test ./backend/config/...` passes

### Task 4.3: Write ConfigManager tests
- **File:** `backend/core/config_test.go` (new)
- **Tests:**
  - `TestSavePutPreservesPasswordHash`: set password_hash, call SavePut with empty auth → verify hash still on disk
  - `TestSavePutUpdatesUsername`: set username via SavePut → verify on disk
  - `TestSavePutNeverOverwritesBaseDataDir`: try to change base_data_dir via SavePut → verify original persists
  - `TestSaveEndpointsOnly`: SaveEndpoints → verify endpoints.yaml changes, system.yaml unchanged
- **Verify:** `go test ./backend/core/...` passes

### Task 4.4: Run full test suite
- `go test ./...`
- `make build`
- E2E tests (if playwright is available)
- **Verify:** All tests pass

## Dependency Order
```
Task 1.1 → Task 1.2 → Task 2.1 → Task 3.1
                                    ↓
Task 4.1 (parallel with 1.3) → Task 4.2 → Task 4.3 → Task 4.4
```
