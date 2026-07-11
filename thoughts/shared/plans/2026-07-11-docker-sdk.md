# Docker SDK Rewrite Implementation Plan

## Dependency Order
```
Task 1 (go.mod) → Task 2 (ssh.go) → Task 3 (runtime.go) → Task 4 (factory.go) → Task 5 (verify)
```

---

## Task 1: Add Docker SDK Dependencies

**File:** `backend/go.mod`

**Changes:**
- Add `github.com/docker/docker v27.0.0` (or latest stable)
- Add `github.com/docker/go-connections v0.5.0` (or latest stable)

**Run:**
```bash
cd backend && go get github.com/docker/docker@latest github.com/docker/go-connections@latest && go mod tidy
```

**Verify:** `go build ./backend/...` passes (existing code still compiles)

---

## Task 2: Create SSH Tunnel Dialer

**File:** `backend/adapter/docker/ssh.go` (new)

**Content:**
- `sshDialer` struct with `*ssh.Client` and `socketPath string`
- `DialContext(ctx, network, addr) (net.Conn, error)` — calls `d.client.Dial("unix", d.socketPath)`
- `NewSSHDialer(cfg *contracts.ConnectionConfig) (*sshDialer, error)` — parses private key via `ssh.ParsePrivateKey`, dials SSH host `cfg.Endpoint` on port 22 with user `cfg.SSHUser`, returns dialer

**Edge cases:**
- Missing port in endpoint → default to 22
- Ed25519 and RSA keys both supported (ssh.ParseRawPrivateKey handles both)
- No private key → return error immediately
- SSH host unreachable → error propagates to caller

**Verify:** `go build ./backend/adapter/docker/...` passes

---

## Task 3: Rewrite Docker Runtime

**File:** `backend/adapter/docker/runtime.go` (rewrite)

**New Runtime struct:**
```go
type Runtime struct {
    client  *client.Client
    cancel  context.CancelFunc
    sshCli  *ssh.Client  // non-nil only for SSH connections
}
```

**NewRuntime(cfg) logic:**
1. Create context with cancel
2. Build `[]client.Opt` based on `cfg.Type`:
   - `unix`: `client.WithHost("unix://" + cfg.Endpoint)`, default `/var/run/docker.sock`
   - `tcp`/`http`: `client.WithHost("tcp://" + cfg.Endpoint)` (http→tcp)
   - `https`: `client.WithHost("tcp://" + cfg.Endpoint)` + TLS transport from `tlsconfig.Client`
   - `ssh`: create `sshDialer` → `client.WithHost("http://docker")` + `client.WithDialContext(dialer.DialContext)`
3. Always: `client.WithAPIVersionNegotiation()` + `client.FromEnv` (allow DOCKER_HOST override)
4. `client.NewClientWithOpts(opts...)`
5. Verify: `cli.Ping(ctx)`

**20 methods → SDK calls (all use `r.client`):**

| Method | SDK | Return conversion |
|---|---|---|
| ContainerRun | ContainerCreate + ContainerStart | → container ID |
| ContainerStop | ContainerStop | → nil |
| ContainerRemove | ContainerRemove(force) | → nil |
| ContainerInspect | ContainerInspect | → toContainerInfo |
| ContainerExec | ContainerExecCreate + ContainerExecAttach | → stdout+stderr string |
| ContainerLogs | ContainerLogs (ReadAll) | → string |
| ContainerList | ContainerList(All) | → map toContainerInfo |
| PullImage | ImagePull | → nil (discard reader) |
| ImageList | ImageList | → map toImageInfo |
| NetworkCreate | NetworkCreate | → network ID |
| NetworkRemove | NetworkRemove | → nil |
| NetworkInspect | NetworkInspect | → toNetworkInfo |
| NetworkList | NetworkList | → map toNetworkInfo |
| NetworkConnect | NetworkConnect | → nil |
| VolumeCreate | VolumeCreate | → volume name/ID |
| VolumeRemove | VolumeRemove(force) | → nil |
| VolumeInspect | VolumeInspect | → toVolumeInfo |
| VolumeList | VolumeList | → map toVolumeInfo |
| Ping | Ping | → nil |
| Info | Info | → toRuntimeInfo |

**Type conversion helpers (same file, unexported):**
- `toContainerInfo(types.Container) contracts.ContainerInfo`
- `toImageInfo(types.ImageSummary) contracts.ImageInfo`
- `toNetworkInfo(types.NetworkResource) contracts.NetworkInfo`
- `toVolumeInfo(types.Volume) contracts.VolumeInfo`
- `toRuntimeInfo(types.Info) contracts.RuntimeInfo`

**Close():**
- `r.cancel()`
- `r.client.Close()`
- If `r.sshCli != nil`, `r.sshCli.Close()`

**Verify:** `go build ./backend/adapter/docker/...` passes

---

## Task 4: Update Endpoint Factory

**File:** `backend/endpoint/factory.go`

**Changes:**
- Remove `os/exec` import
- Remove `exec.LookPath("docker")` and `exec.LookPath("podman")` auto-detection
- Replace with:
  ```go
  engine := cfg.Engine
  if engine == "" || engine == contracts.EngineTypeAuto {
      engine = contracts.EngineTypeDocker  // default to Docker SDK
  }
  ```

**Verify:** `go build ./backend/endpoint/...` passes

---

## Task 5: Build and Test

**Verify:**
```bash
go build ./backend/...       # full build
go vet ./backend/...         # static analysis
go test ./backend/...        # all tests pass
```

**Manual test:**
```bash
cd backend && go run . -c ../.selfhosted.dev/ --addr :18080
# GET http://localhost:18080/api/health → {"status":"ok","endpoints":1}
# GET http://localhost:18080/api/containers?all=true → array of containers
```
