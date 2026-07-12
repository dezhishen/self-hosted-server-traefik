---
date: 2026-07-12
topic: "Contracts Completeness, SDK Implementation, SSH Fix, Log Encapsulation"
status: validated
---

## Problem Statement

Four interconnected issues in the self-hosted server codebase:

1. **Contracts/SDK gap**: The `sdk/` package has only 2 of 19+ backend API endpoints implemented. Most methods are stubs returning "not implemented". No SDK method exists for SSH operations, migrations, containers, endpoints listing, or individual service operations.

2. **SSH key flow broken**: After generating an SSH key, the endpoint listing doesn't include SSH metadata (fingerprint, type, public key), so the frontend can't tell which endpoints have keys. The authorize endpoint fails with "no SSH key configured" after server restart because `SSHPublicKey` isn't persisted in YAML config.

3. **Zap logging leak**: `"go.uber.org/zap"` is imported directly in 11 files across the codebase. Every module that needs logging reaches into the zap dependency, making it impossible to swap loggers or enforce consistent logging patterns.

4. **Test coverage**: Existing tests cover only basic SSH keygen and contract constants. No tests for SDK methods, SSH authorize, endpoint listing, or the logging package.

---

## Constraints

- The SDK must be a standalone Go package — can't import backend internals
- SSH private keys must NEVER be exposed via JSON API (currently correctly tagged with `json:"-"`)
- Log encapsulation must NOT break any existing consumer — the interface must be drop-in compatible
- All tests must pass after each change
- Contracts package is the shared type system — types used by both backend and SDK must live there

---

## Approach

I'm taking a four-track approach, ordered by dependency:

1. **Log encapsulation first** — create the `backend/logger` package so the rest of the codebase uses a consistent interface
2. **SSH fixes** — three targeted fixes to `server.go` and `ssh.go` in the server package
3. **SDK implementation** — implement all missing SDK methods using the existing `doJSON` infrastructure
4. **Tests** — comprehensive tests for all new and modified code

---

## Architecture

### Track 1: Logger Package

```
backend/logger/
  logger.go    - Logger interface with Info/Warn/Error/With/Sync
  zap.go       - zapAdapter implementing Logger (only file importing zap)
```

**Logger interface:**
```go
type Logger interface {
    Info(msg string, fields ...Field)
    Warn(msg string, fields ...Field)
    Error(msg string, fields ...Field)
    With(fields ...Field) Logger
    Sync() error
}

type Field = ...  // opaque wrapper, not exposed as zap.Field
```

The `zapAdapter` wraps `*zap.Logger` and delegates to it. The existing `InitLogger` in `core/log.go` becomes a function on the logger package that returns `logger.Logger`.

All 11 files currently importing `"go.uber.org/zap"` will import `"github.com/.../backend/logger"` instead. Where they accept a logger parameter, the type changes from `*zap.Logger` to `logger.Logger`.

**Key insight:** The SDK doesn't currently log, but if it needs to in the future, it'll use the same `logger` package — no SDK dependency on zap.

### Track 2: SSH Fixes

Three changes, all in `backend/internal/server/`:

**Fix 1 — `handleEndpoints` in server.go:** Before marshaling endpoint configs, iterate and call `computeSSHKeyMeta` on each endpoint that has a private key. This makes SSH metadata visible in the endpoint listing response.

**Fix 2 — `handleSSHAuthorize` in ssh.go:** Change the guard check from `SSHPublicKey == ""` to `SSHPrivateKey == ""`. Private keys are always persisted (they have `yaml:"ssh_private_key,omitempty"`). Also call `computeSSHKeyMeta` at the top of the handler to ensure computed fields are available after restart.

**Fix 3 — `NewApp` in app.go:** After loading endpoints but before creating runtime contexts, iterate endpoints and call `computeSSHKeyMeta` on any with SSHPrivateKey. This ensures SSH metadata is available from startup, not just after first GET /api/config.

### Track 3: SDK Implementation

All new methods follow the established `doJSON` pattern. The SDK only depends on `contracts` for types and standard lib for HTTP.

**New SDK methods (by API group):**

| API Group | Method | HTTP |
|-----------|--------|------|
| Auth | `Logout()` | POST /api/auth/logout |
| Health | `Health()` | GET /api/health |
| Endpoints | `ListEndpoints()` | GET /api/endpoints |
| Config | `GetConfig()`, `UpdateConfig(cfg)`, `UpdatePassword(pw)` | GET/PUT /api/config, POST /api/config/password |
| Services (list) | `List(cat, query)`, `GetService(name)` | GET /api/services, GET /api/services/{name} |
| Services (actions) | `Install(name, params)`, `Uninstall(name)`, `ServiceStatus(name)`, `Restart(name)`, `ServiceLogs(name, tail)`, `RenderConfig(name, params)` | POST/DELETE actions |
| Params | `ServiceParams(name)`, `UpdateServiceParams(name, pv)` | POST/PUT /api/services/{name}/params |
| Containers | `ListContainers(all)` | GET /api/containers |
| Migration | `MigrateAnalyze()`, `MigrateExecute(req)` | GET/POST /api/migrate/* |
| SSH | `SSHKeygen(name, keyName, type)`, `SSHImport(name, privKey)`, `SSHListKeys()`, `SSHAuthorize(name, password)` | POST/GET/POST |
| Subscriptions | `SubSync(name)` | POST /api/subscriptions/{name}/sync |

Each method returns typed results using contracts types or inline result structs (defined in SDK package since they're response-only shapes).

### Track 4: Tests

**Server tests (backend/internal/server):**
- `TestEndpointsListWithSSHMetadata` — verify computeSSHKeyMeta is called in handleEndpoints
- `TestSSHAuthorizeNoKey` — verify proper error when no SSHPrivateKey
- `TestSSHAuthorizeWithKey` — verify accept flow with generated key (mock SSH server)

**SDK tests (sdk/):**
- Table-driven tests using `httptest.NewServer` for each new method
- Verify request construction, header auth, response parsing
- Error cases: 4xx/5xx responses, malformed JSON

**Logger tests (backend/logger):**
- Verify adapter produces correct output
- Verify With() creates child logger
- Verify Sync() doesn't panic

---

## Data Flow

### SSH Key Generation + Authorization (fixed)

```
[Frontend]                   [Backend]                      [Config]
   |                            |                              |
   |-- POST /api/ssh/keygen -->|                              |
   |                            |-- generate key pair         |
   |                            |-- store in endpoint config  |
   |                            |-- compute metadata          |
   |                            |-- SaveEndpoints() --------->|
   |                            |-- RefreshEndpoints()        |
   |<-- keygenResponse --------|                              |
   |                            |                              |
   |-- GET /api/endpoints ---->|                              |
   |                            |-- computeSSHKeyMeta(each)   |
   |<-- eps[].ssh_key_* ------|                              |
   |                            |                              |
   |-- POST /api/ssh/authorize>|                              |
   |                            |-- check SSHPrivateKey != "" |
   |                            |-- computeSSHKeyMeta (fresh) |
   |                            |-- SSH dial + install key    |
   |<-- {status: "ok"} -------|                              |
```

### Logging (encapsulated)

```
[Any module]                  [backend/logger]               [zap]
   |                            |                              |
   |-- logger.Info(msg, flds)->|                              |
   |                            |-- zapAdapter.Info(msg, flds)|
   |                            |                              |-- zapLogger.Info(...)
   |                            |<-----------------------------|
   |<--------------------------|                              |
```

---

## Error Handling

**Logger:** The adapter catches panics from zap (shouldn't happen). Sync() errors are logged but not propagated — logging should never crash the app.

**SSH:** The `computeSSHKeyMeta` function silently clears metadata if private key parsing fails — this is correct behavior (stale metadata is worse than no metadata).

**SDK:** HTTP 4xx/5xx responses are returned as `fmt.Errorf("API error (%d): %s", code, body)` — the SDK doesn't parse JSON errors since different endpoints return different error shapes. Callers can inspect the string if needed.

---

## Testing Strategy

- **Unit tests** for every new SDK method using `httptest.NewServer` — no real server needed
- **Unit tests** for SSH authorize with generated keys (the existing pattern)  
- **Mock SSH server** for the authorize test — listens on a random port, accepts password auth, allows key installation
- **Logger tests** verify the adapter contract — output format, field propagation, child logger isolation

---

## Open Questions

- Should the SDK accept an optional `endpointName` header parameter for multi-endpoint operations? Currently operations like Install use `endpoint.Context` via header `X-Remote-Name`. The SDK will accept an optional `EndpointName` string in each method call.
- The `Serve` method in SDK was a stub — it doesn't make sense as an SDK method (serving is a server concern). I'm replacing it with a proper method or removing it entirely.
