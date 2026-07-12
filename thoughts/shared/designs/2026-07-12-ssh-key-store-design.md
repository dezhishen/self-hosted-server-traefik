---
date: 2026-07-12
topic: "Independent SSH Key Store"
status: validated
---

## Problem Statement

SSH private keys are currently embedded directly in `endpoints.yaml` within `ConnectionConfig.SSHPrivateKey`. This design has four problems:

1. **Key lifecycle is tied to endpoint lifecycle** — keygen/import are side-effects on endpoint config, not independent operations
2. **No key reuse** — two endpoints using the same SSH key must duplicate the private key in storage
3. **PUT /api/config has leaky SSH semantics** — it must intrusively preserve the server-side-only `SSHPrivateKey` from existing config when the frontend sends a config update
4. **No independent key management** — no way to list, delete, or rotate keys independently of endpoints

## Constraints

- SSH private key must NEVER be exposed via JSON API (`json:"-"`)
- Private key must never leave the server (not returned to client in any response)
- Backward-compatible JSON API surface for the frontend (SSH metadata fields must still appear in endpoint JSON)
- All existing adapter code (`newSSHDialer`, Docker runtime SSH tunnel) should change as little as possible
- All existing tests must pass after migration
- `go build ./backend/... ./sdk/... ./contracts/...` and `go test ./backend/... ./sdk/... ./contracts/...` must pass

## Approach

Introduce a **standalone SSH key store file** (`ssh_keys.yaml`) managed by a dedicated `SSHKeyManager`. Endpoints no longer embed SSH key data — they reference a key by name via `SSHKeyRef`. At runtime (JSON serialization, SSH connection initiation), the key data is resolved from the key store.

**"Store by reference, resolve at runtime."**

## Architecture

```
{baseDataDir}/config/
  system.yaml          — auth, base_data_dir (unchanged)
  endpoints.yaml       — endpoint definitions with ssh_key_ref (changed)
  ssh_keys.yaml        — NEW: standalone SSH key store
```

The `SSHKeyManager` is loaded at `App` initialization, alongside `ConfigManager`. The `App` wires key resolution into two places:

- **Runtime init** (`initEndpointContext`): resolves `SSHKeyRef` → fills `SSHPrivateKey` for the adapter
- **JSON serialization** (GET /api/config handler): resolves `SSHKeyRef` → fills metadata fields (fingerprint, type, public key)

## Components

### 1. `contracts/sshkey.go` (new)

```go
type SSHKeyEntry struct {
    Name        string `yaml:"name" json:"name"`
    PrivateKey  string `yaml:"private_key" json:"-"`          // never JSON
    PublicKey   string `yaml:"public_key" json:"public_key"`
    Fingerprint string `yaml:"fingerprint" json:"fingerprint"`
    KeyType     string `yaml:"key_type" json:"key_type"`
    CreatedAt   string `yaml:"created_at" json:"created_at"`
    Comment     string `yaml:"comment,omitempty" json:"comment,omitempty"`
}

type SSHKeyStore struct {
    Keys map[string]*SSHKeyEntry `yaml:"keys" json:"keys"`
}
```

### 2. `contracts/runtime.go` — ConnectionConfig changes

```go
type ConnectionConfig struct {
    // ... existing fields unchanged ...
    SSHUser           string         `yaml:"ssh_user,omitempty" json:"ssh_user,omitempty"`
    SSHKeyRef         string         `yaml:"ssh_key_ref,omitempty" json:"ssh_key_ref,omitempty"`  // NEW
    SSHPrivateKey     string         `yaml:"-" json:"-"`  // CHANGED from yaml:"ssh_private_key,omitempty"
    SSHKeyFingerprint string         `yaml:"-" json:"ssh_key_fingerprint,omitempty"`  // same
    SSHKeyType        string         `yaml:"-" json:"ssh_key_type,omitempty"`           // same
    SSHPublicKey      string         `yaml:"-" json:"ssh_public_key,omitempty"`         // same
}
```

Key changes:
- `SSHPrivateKey` goes from `yaml:"ssh_private_key,omitempty"` to `yaml:"-"` — never persisted to YAML, only populated at runtime
- `SSHKeyRef` added — the reference that gets persisted in `endpoints.yaml`
- Metadata fields (fingerprint, type, public key) unchanged — still `yaml:"-"`, populated at JSON serialization time

### 3. `backend/core/sshkey_manager.go` (new)

```
SSHKeyManager
├── private fields: path, mu sync.RWMutex, keys map[string]*contracts.SSHKeyEntry
├── Load() — reads ssh_keys.yaml, returns error if not exist
├── Save() — writes ssh_keys.yaml
├── Get(name) → (*SSHKeyEntry, bool)
├── Set(entry) — upsert, calls Save
├── Delete(name) — removes key, calls Save
├── List() → []*SSHKeyEntry (without PrivateKey for safety)
├── Resolve(keyRef) → (fingerprint, keyType, publicKey) — for JSON serialization
└── GetPrivateKey(keyRef) → (string, bool) — for SSH tunnel init
```

Load/Save use a file lock for safety. Save auto-creates the config directory if missing.

### 4. `backend/core/app.go` — modifications

- New field: `sshKeyManager *SSHKeyManager`
- `NewApp()` initializes SSHKeyManager after ConfigManager
- `initEndpointContext()` resolves `ssh_key_ref` before creating runtime:

```go
func (a *App) initEndpointContext(name string, epCfg *contracts.EndpointConfig) (*endpoint.Context, error) {
    cfg := *epCfg.Connection
    if cfg.SSHKeyRef != "" {
        key, ok := a.sshKeyManager.Get(cfg.SSHKeyRef)
        if !ok {
            return nil, fmt.Errorf("SSH key %q not found for endpoint %q", cfg.SSHKeyRef, name)
        }
        cfg.SSHPrivateKey = key.PrivateKey
    }
    runtime, err := endpoint.CreateRuntime(cfg, a.Config.BaseDataDir)
    // ... rest unchanged
}
```

- `RefreshEndpoints()` unchanged (still iterates Config.Endpoints and calls initEndpointContext)

### 5. `backend/internal/server/ssh.go` — API handlers rewritten

**`handleSSHKeygen`:**
1. Validates input (name required, key_type optional with ed25519 default)
2. Generates key pair (existing logic)
3. Creates `SSHKeyEntry` in `s.app.sshKeyManager.Set()`
4. If `endpoint_name` provided:
   a. Gets or creates endpoint in `s.app.Config.Endpoints`
   b. Sets `ep.Connection.SSHKeyRef = keyName`
   c. Saves endpoints via `s.app.configManager.SaveEndpoints()`
5. Returns SSHKeyInfo (name, public_key, fingerprint, type)

**`handleSSHImport`:**
Same pattern as keygen but parses existing private key.

**`handleSSHKeys`:**
Returns `s.app.sshKeyManager.List()` — names, fingerprints, types, public keys.

**`handleSSHKeyDelete` (new):**
1. Deletes from key store via `s.app.sshKeyManager.Delete()`
2. Scans all endpoints for references to this key
3. Clears `ssh_key_ref` on any endpoint referencing the deleted key
4. Returns 204

**`handleSSHAuthorize`:**
1. Request includes `{ endpoint_name, key_ref, password }`
2. Resolves public key from `s.app.sshKeyManager.Get(keyRef).PublicKey`
3. Existing authorize logic unchanged (connects via password, writes to authorized_keys)

**`computeSSHKeyMeta` removed** — replaced by `SSHKeyManager.Resolve()`

### 6. `backend/internal/server/server.go` — handler changes

**Route registration additions:**
```go
mux.HandleFunc("/api/ssh/keys/{name}", s.handle(s.withAuth(s.handleSSHKeyDelete)))
mux.HandleFunc("/api/endpoints/{name}", s.handle(s.withAuth(s.handleEndpointPut)))
mux.HandleFunc("/api/endpoints/{name}", s.handle(s.withAuth(s.handleEndpointDelete)))
mux.HandleFunc("/api/endpoints/{name}/refresh", s.handle(s.withAuth(s.handleEndpointRefresh)))
```

**GET /api/config — metadata resolution:**
```go
for name, ep := range s.app.Config.Endpoints {
    if ep.Connection != nil && ep.Connection.SSHKeyRef != "" {
        meta, ok := s.app.sshKeyManager.Get(ep.Connection.SSHKeyRef)
        if ok {
            ep.Connection.SSHPublicKey = meta.PublicKey
            ep.Connection.SSHKeyFingerprint = meta.Fingerprint
            ep.Connection.SSHKeyType = meta.KeyType
        }
    }
}
```

**PUT /api/config — simplified:**
- Remove the SSHPrivateKey preservation logic entirely
- The incoming endpoints have `ssh_key_ref` instead of embedded private key
- Still validates that referenced keys exist

**Dedicated endpoint CRUD (new handlers):**

`handleEndpointPut`:
1. Decode `{ connection, default }` from body
2. Validate
3. Upsert into `s.app.Config.Endpoints`
4. Save endpoints via configManager
5. Refresh runtime for this endpoint
6. Return 200

`handleEndpointDelete`:
1. Remove from `s.app.Config.Endpoints`
2. Remove runtime context
3. Save endpoints
4. Return 204

`handleEndpointRefresh`:
1. Tear down existing runtime context
2. Re-init via initEndpointContext
3. Return 200 with status

## Data Flow

### Key Generation Flow
```
Client                    Server
  │                         │
  │ POST /api/ssh/keygen    │
  │ { name, key_type }      │
  │─────►─────────────────►│
  │                         │ generateKeyPair()
  │                         │ sshKeyManager.Set(entry)
  │                         │ sshKeyManager.Save() → ssh_keys.yaml
  │◄───────◄───────────────│
  │ { name, public_key,    │
  │   fingerprint, type }   │
```

### Key Generation + Assign to Endpoint Flow
```
  │                         │
  │ POST /api/ssh/keygen    │
  │ { name, key_type,       │
  │   endpoint_name }       │
  │─────►─────────────────►│
  │                         │ generateKeyPair()
  │                         │ sshKeyManager.Set(entry)
  │                         │ ep.Connection.SSHKeyRef = name
  │                         │ configManager.SaveEndpoints()
  │◄───────◄───────────────│
  │ { name, public_key,    │
  │   fingerprint, type }   │
```

### GET /api/config Flow (metadata resolution)
```
  │                         │
  │ GET /api/config         │
  │─────►─────────────────►│
  │                         │ for each endpoint:
  │                         │   if ssh_key_ref exists:
  │                         │     key = sshKeyManager.Get(ref)
  │                         │     ep.Connection.SSHPublicKey = key.PublicKey
  │                         │     ep.Connection.SSHKeyFingerprint = key.Fingerprint
  │                         │     ep.Connection.SSHKeyType = key.KeyType
  │                         │ marshal JSON → response
  │◄───────◄───────────────│
  │ { endpoints: {          │
  │   myserver: {           │
  │     connection: {       │
  │       ssh_key_ref,      │
  │       ssh_public_key,   │
  │       ssh_fingerprint,  │
  │       ssh_key_type      │ ← all resolved from store
  │ } } }                   │
```

### Runtime Init Flow (SSH tunnel creation)
```
RefreshEndpoints()
  │
  ├── for each endpoint in Config.Endpoints:
  │     │
  │     ├── initEndpointContext(name, epCfg):
  │     │     │
  │     │     ├── if epCfg.Connection.SSHKeyRef != "":
  │     │     │     key = sshKeyManager.Get(ref)
  │     │     │     cfg.SSHPrivateKey = key.PrivateKey  ← fill in for adapter
  │     │     │
  │     │     ├── CreateRuntime(cfg) → Docker Runtime
  │     │     │     └── newSSHDialer(cfg)  ← reads cfg.SSHPrivateKey (populated above)
  │     │     │
  │     │     └── return endpoint.Context
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Key ref points to non-existent key | `initEndpointContext` returns error → endpoint marked as degraded (with error stored in context) |
| Key store file doesn't exist on startup | Create empty key store (no keys, no error) |
| Key store file corrupted | Return load error, App startup fails with clear message |
| Key deletion while referenced by endpoints | Delete key + clear all `ssh_key_ref` references in endpoints; save endpoints |
| Duplicate key name on Set | Upsert (replace existing, as with map semantics) |

## Testing Strategy

### Unit Tests

1. **`contracts/sshkey_test.go`** — struct serialization/deserialization, yaml + json round-trip (verify `PrivateKey` has `json:"-"`)
2. **`backend/core/sshkey_manager_test.go`** — load/save/get/set/delete cycle with temp file
3. **`backend/internal/server/ssh_test.go`** — rewrite existing tests:
   - Keygen without endpoint_name (creates key in store only)
   - Keygen with endpoint_name (creates key + sets ref)
   - Keygen invalid type → 400
   - Keygen duplicate name → 200 (upsert)
   - Delete key → 204
   - Delete non-existent key → 404
   - Delete key that is referenced → 204 + clears refs
   - Import key
   - List keys (returns metadata, no private key)
   - Authorize with key_ref

### Integration Tests

- Full flow: create endpoint → generate key → verify endpoint JSON has resolved metadata → authorize → use endpoint → delete key → verify endpoint ref cleared
- PUT /api/config with endpoint containing ssh_key_ref → saved correctly, no SSH private key in endpoints.yaml

### E2E Tests (Playwright)

Update `settings-ssh.spec.ts` to match new API behavior:
- Keygen creates key in store, endpoint shows key info
- Import creates key in store
- Key info appears in endpoint card (resolved from store)

## Open Questions

1. **Migration from old format** — endpoints that have `ssh_private_key` embedded need migration on first load. Should `ConfigManager.Load()` detect old-format endpoints and extract keys into the key store automatically?
   - Decision: **Yes, auto-migrate on first load**. If an endpoint has `SSHPrivateKey` set, extract it to the key store with an auto-generated name, set `SSHKeyRef`, and clear `SSHPrivateKey`. One-time migration.

2. **Key name generation for migration** — what naming convention?
   - Decision: Use pattern `{endpoint_name}-key`. If conflict, append `-1`, `-2`, etc.

3. **Thread safety** — `SSHKeyManager` uses `sync.RWMutex`. Should there be a write lock for Save?
   - Decision: Yes. All mutating operations (Set, Delete) acquire write lock + call Save. Read operations (Get, List, Resolve) use read lock.

4. **Frontend endpoint_name in keygen** — should keygen require endpoint_name or make it optional?
   - Decision: **Optional**. If provided, assign the key. If not, just create in store (user can assign later).

5. **SSH adapter `newSSHDialer` error handling** — currently returns error if `SSHPrivateKey` is empty. With key ref, `initEndpointContext` ensures it's populated, but what about edge cases (key deleted between validation and use)?
   - Decision: `newSSHDialer` still checks for empty private key as safety net. The error message will be clear: "SSH private key is required" (unchanged).
