# Implementation Plan: Contracts/SDK/SSH/Log Tasks

## Track 1: Logger Encapsulation (Dependency — do first)

### Task 1.1: Create `backend/logger/` package
- **File:** `backend/logger/logger.go`
- Logger interface: `Info(msg string, fields ...Field)`, `Warn`, `Error`, `With(fields ...Field) Logger`, `Sync() error`
- `Field` type: opaque struct wrapping `zap.Field`
- Constructor: `NewNop() Logger` for tests
- **File:** `backend/logger/zap.go`
- `zapAdapter` struct implementing Logger, wrapping `*zap.Logger`
- `InitLogger(baseDir string) Logger` — replaces `core.InitLogger`
- `NewZapLogger() *zap.Logger` for internal use only (configmanager etc that need raw zap)
- **Test:** `backend/logger/logger_test.go`
- Test adapter produces output, With() creates child, Sync() doesn't panic

### Task 1.2: Update `backend/core/log.go`
- Replace `InitLogger` with call to `logger.InitLogger`
- Remove direct zap imports

### Task 1.3: Update `backend/core/app.go`
- Change `Logger *zap.Logger` to `Logger logger.Logger`
- In `NewApp`, use `logger.InitLogger` instead of `core.InitLogger`
- Update all `zap.String`, `zap.Error`, `zap.Any` calls to `logger.String`, `logger.Error`, `logger.Any`

### Task 1.4: Update `backend/internal/server/server.go`
- Replace `*zap.Logger` with `logger.Logger` in Server struct
- Update `withLogging` and all zap field calls

### Task 1.5: Update `backend/internal/server/errors.go`
- Replace `zap.String`, `zap.Error`, `zap.Int` with logger equivalents
- `writeError` method uses `logger.Logger`

### Task 1.6: Update `backend/internal/server/ssh.go`
- Replace zap field calls with logger field calls

### Task 1.7: Update `backend/internal/server/apikey.go`
- Replace `*zap.Logger` with `logger.Logger`
- Replace zap field calls

### Task 1.8: Update `backend/internal/server/ssh_test.go`
- Replace `zap.NewNop()` with `logger.NewNop()`

### Task 1.9: Update `backend/endpoint/context.go`
- Replace `*zap.Logger` with `logger.Logger`

### Task 1.10: Update `backend/endpoint/manager.go`
- Replace `*zap.Logger` with `logger.Logger`
- Replace all zap field calls

### Task 1.11: Update `backend/endpoint/migrate.go`
- Replace zap field calls with logger field calls

### Task 1.12: Update `backend/subscription/manager.go`
- Replace `*zap.Logger` with `logger.Logger`
- Replace zap field calls

## Track 2: SSH Fixes (after Track 1)

### Task 2.1: Fix `handleEndpoints` in `server.go`
- In `handleEndpoints`, iterate endpoints, if `Connection != nil && Connection.SSHPrivateKey != ""`, call `computeSSHKeyMeta(ep.Connection)`

### Task 2.2: Fix `handleSSHAuthorize` in `ssh.go`
- Change guard: `if epCfg.Connection == nil || epCfg.Connection.SSHPrivateKey == ""`
- At handler start: `if epCfg.Connection != nil && epCfg.Connection.SSHPrivateKey != "" { computeSSHKeyMeta(epCfg.Connection) }`

### Task 2.3: Fix `NewApp` in `app.go`
- After loading config endpoints, iterate and compute SSH metadata:
```go
for _, ep := range cfg.Endpoints {
    if ep.Connection != nil && ep.Connection.SSHPrivateKey != "" {
        computeSSHKeyMeta(ep.Connection)
    }
}
```

## Track 3: SDK Implementation (after Tracks 1-2)

### Task 3.1: Implement SDK auth methods
- `Logout()` → POST /api/auth/logout
- Replace existing stubs in `sdk/client.go`

### Task 3.2: Implement SDK health + config methods
- `Health() (*HealthResult, error)` → GET /api/health
- `ListEndpoints() ([]*contracts.EndpointConfig, error)` → GET /api/endpoints
- `GetConfig() (*contracts.AppConfig, error)` → GET /api/config
- `UpdateConfig(cfg *contracts.AppConfig) error` → PUT /api/config
- `UpdatePassword(password string) error` → POST /api/config/password

### Task 3.3: Implement SDK service methods
- `List(category, query string) ([]*contracts.ServiceDefinition, error)` → GET /api/services
- `GetService(name string) (*ServiceDetail, error)` → GET /api/services/{name}
- `Install(name string, params []*contracts.ParamValue, endpointName string) (string, error)` → POST /api/services
- `DeleteService(name string, endpointName string) error` → DELETE /api/services/{name}
- `ServiceStatus(name, endpointName string) (*contracts.ServiceStatusResult, error)` → POST /api/services/{name}/status
- `ServiceRestart(name, endpointName string) error` → POST /api/services/{name}/restart
- `ServiceLogs(name, endpointName string, tail int) (string, error)` → POST /api/services/{name}/logs
- `RenderConfig(name string, params []*contracts.ParamValue, endpointName string) (map[string]string, error)` → POST /api/services/{name}/render
- `ServiceParams(name, endpointName string) ([]*contracts.ParamValue, error)` → POST /api/services/{name}/params
- `UpdateServiceParams(name string, pv *contracts.ParamValue, endpointName string) error` → PUT /api/services/{name}/params

### Task 3.4: Implement SDK container + migration methods
- `ListContainers(all bool, endpointName string) ([]*contracts.ContainerInfo, error)` → GET /api/containers
- `MigrateAnalyze(endpointName string) ([]*contracts.MigrationCandidate, error)` → GET /api/migrate/analyze
- `MigrateExecute(req *contracts.MigrationRequest, endpointName string) (string, error)` → POST /api/migrate/execute

### Task 3.5: Implement SDK SSH methods
- `SSHKeygen(endpointName, keyName, keyType string) (*SSHKeygenResult, error)` → POST /api/ssh/keygen
- `SSHImport(endpointName, privateKey string) (*SSHKeygenResult, error)` → POST /api/ssh/import
- `SSHListKeys() ([]*SSHKeyInfo, error)` → GET /api/ssh/keys
- `SSHAuthorize(endpointName, password string) error` → POST /api/ssh/authorize

### Task 3.6: Implement SDK subscription methods
- `SubAdd(name, url string) error` → POST /api/subscriptions
- `SubRemove(name string) error` → DELETE /api/subscriptions/{name}
- `SubList() ([]*contracts.Subscription, error)` → GET /api/subscriptions
- `SubSync(name string) error` → POST /api/subscriptions/{name}/sync

### Task 3.7: Remove Serve stub, add response types
- Remove `Serve` method
- Add `SSHKeygenResult`, `SSHKeyInfo`, `HealthResult` structs in SDK
- Accept optional endpointName for endpoint-scoped methods

## Track 4: Tests

### Task 4.1: Logger tests
- `backend/logger/logger_test.go` — test Info/Warn/Error output, With() chaining, Sync()

### Task 4.2: SDK tests
- Add test cases in `sdk/sdk_test.go` using `httptest.NewServer`
- Test each new method: verify request method/path/headers, verify response parsing
- Test error handling (4xx/5xx responses)

### Task 4.3: SSH tests
- Add to `backend/internal/server/ssh_test.go`:
  - `TestEndpointsListWithSSHMetadata` — verify SSH fields present after keygen
  - `TestSSHAuthorizeNoKey` — verify error when no private key
