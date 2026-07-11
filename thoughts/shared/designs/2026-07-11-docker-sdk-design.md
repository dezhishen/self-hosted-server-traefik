---
date: 2026-07-11
topic: "Docker Adapter — Replace CLI with Go SDK"
status: validated
---

## Problem Statement

Using `exec.Command("docker", args...)` in `backend/adapter/docker/runtime.go` requires the `docker` CLI binary to be available in PATH. In containerized deployments, this binary is often absent. When `exec.LookPath("docker")` fails in `NewRuntime()`, the endpoint creation fails silently, the endpoint is skipped (in `core/app.go`'s `initEndpointContext`), and subsequent API calls return `404 "endpoint not found: default"`.

**Root cause:** `backend/endpoint/factory.go` calls `exec.LookPath("docker")` to auto-detect the engine. If not found, `NewRuntime` returns error → `NewApp` logs warn and continues → endpoint map is empty → "endpoint not found: default".

## Constraints

- All 20 methods in `ContainerRuntime` interface must be supported
- All connection types must work: unix, tcp, http, https, ssh
- TLS cert/key support must be preserved
- SSH private key support must be preserved (keys stored server-side via new keygen/import APIs)
- Backward compatible — no changes to contracts or server handler signatures
- Podman adapter (`backend/adapter/podman/runtime.go`) is NOT affected (keeps CLI-based approach)

## Approach

Replace `exec.Command("docker", ...)` with `github.com/docker/docker/client` (Docker SDK). The SDK communicates directly with the Docker daemon API over the configured socket/transport — no CLI needed. For SSH connections, create a custom `DialContext` that tunnels through `golang.org/x/crypto/ssh` (already in go.mod).

## Architecture

**Before (`runtime.go`):**
```
Runtime { binary, cfg, tempDir }
  → docker(args...) → exec.Command + env vars (DOCKER_HOST, DOCKER_TLS_VERIFY, etc.)
  → 20 wrapper methods calling docker()
```

**After (`runtime.go` + `ssh.go`):**
```
Runtime { client, cancel, sshCli }
  → SDK client per connection type
  → SSH connections via custom DialContext
  → 20 wrapper methods calling SDK methods + type conversion
```

## Components

### `backend/adapter/docker/runtime.go` — Rewrite

**Runtime struct:**
```
Runtime {
    client  *client.Client      // Docker SDK client
    cancel  context.CancelFunc  // for Close()
    sshCli  *ssh.Client         // non-nil only for SSH connections
}
```

**NewRuntime(cfg)** — creates SDK client from connection config:
- `unix`: `client.WithHost("unix://" + cfg.Endpoint)`
- `tcp`/`http`: `client.WithHost("http://" + cfg.Endpoint)`
- `https`: `client.WithHost("https://" + cfg.Endpoint)` + TLS config via `tlsconfig.Client`
- `ssh`: create SSH dialer → `client.WithDialContext(dialer.DialContext)` + dummy host

All paths: `client.WithAPIVersionNegotiation()` for cross-version compatibility.

**Method mapping (20 methods → SDK calls):**

| Method | SDK Call |
|---|---|
| ContainerRun | ContainerCreate → ContainerStart |
| ContainerStop | ContainerStop |
| ContainerRemove | ContainerRemove |
| ContainerInspect | ContainerInspect → convert to ContainerInfo |
| ContainerExec | ContainerExecCreate → ContainerExecAttach → read stdout/stderr |
| ContainerLogs | ContainerLogs → read all → string |
| ContainerList | ContainerList → convert each |
| PullImage | ImagePull |
| ImageList | ImageList → convert each |
| NetworkCreate | NetworkCreate |
| NetworkRemove | NetworkRemove |
| NetworkInspect | NetworkInspect → convert |
| NetworkList | NetworkList → convert each |
| NetworkConnect | NetworkConnect |
| VolumeCreate | VolumeCreate |
| VolumeRemove | VolumeRemove |
| VolumeInspect | VolumeInspect → convert |
| VolumeList | VolumeList → convert each |
| Ping | Ping |
| Info | Info → convert to RuntimeInfo |

**Type conversion layer** — small helper functions in the same file:
- `toContainerInfo(types.Container) contracts.ContainerInfo`
- `toImageInfo(types.ImageSummary) contracts.ImageInfo`
- `toNetworkInfo(types.NetworkResource) contracts.NetworkInfo`
- `toVolumeInfo(types.Volume) contracts.VolumeInfo`
- `toRuntimeInfo(types.Info) contracts.RuntimeInfo`

### `backend/adapter/docker/ssh.go` — New

Small SSH tunnel dialer:
```
type sshDialer struct {
    client     *ssh.Client
    socketPath string  // default: /var/run/docker.sock
}

func (d *sshDialer) DialContext(ctx context.Context, network, addr string) (net.Conn, error) {
    return d.client.Dial("unix", d.socketPath)
}
```

`NewSSHDialer(cfg ConnectionConfig)` creates SSH client with key auth and returns dialer.

### `backend/endpoint/factory.go` — Small change

Remove `exec.LookPath("docker")` auto-detect. When `engine == "" || engine == "auto"`, default to Docker SDK directly:
```
if engine == "" || engine == EngineTypeAuto {
    engine = EngineTypeDocker  // no CLI needed
}
```

## Data Flow

### SDK Client Creation
```
NewRuntime(cfg)
  → switch cfg.Type
    case unix:
      client.WithHost("unix:///var/run/docker.sock")
    case tcp/http:
      client.WithHost("http://host:2375")  
    case https:
      client.WithHost("https://host:2375")
      client.WithHTTPClient(tlsTransport)
    case ssh:
      sshDialer = NewSSHDialer(cfg)
      client.WithHost("http://docker")  // dummy
      client.WithDialContext(sshDialer.DialContext)
  → client.WithAPIVersionNegotiation()
  → client.NewClientWithOpts(...)
  → return Runtime{client, cancel, sshCli}
```

### SSH Tunnel
```
NewSSHDialer(cfg)
  → ssh.ParsePrivateKey(cfg.SSHPrivateKey)
  → ssh.Dial("tcp", host+":22", sshConfig)
  → return sshDialer{sshClient, cfg.Endpoint (socket path)}

DialContext(ctx, network, addr)
  → sshClient.Dial("unix", socketPath)
  → returns net.Conn (tunneled to remote host's Docker socket)
```

## Error Handling

- **Docker daemon unreachable:** SDK returns connection error → propagates up as `Ping()` or first API call error
- **Invalid SSH key:** `ParsePrivateKey` fails → `NewRuntime` returns error with "invalid SSH key"
- **SSH host unreachable:** `ssh.Dial` fails → `NewRuntime` returns error with timeout/refused
- **API version mismatch:** `WithAPIVersionNegotiation()` handles this automatically
- **TLS config errors:** malformed cert → `tlsconfig.Client` returns error → `NewRuntime` fails early

## Files Affected

| File | Change |
|---|---|
| `backend/adapter/docker/runtime.go` | Rewrite: CLI → SDK + type conversion |
| `backend/adapter/docker/ssh.go` | New: SSH tunnel dialer (~40 lines) |
| `backend/endpoint/factory.go` | Remove `exec.LookPath`, default to EngineTypeDocker |
| `backend/go.mod` | Add `github.com/docker/docker` + `github.com/docker/go-connections` |

No changes to contracts, server handlers, or podman adapter.

## Testing Strategy

1. **Compile check** — `go build ./backend/...` passes
2. **Existing tests** — `go test ./...` passes unchanged
3. **Manual verification** — start backend with `.selfhosted.dev/` config (SSH endpoint), verify `GET /api/containers?all=true` returns containers
4. **Unit tests for type conversion** (optional, non-blocking)

## Open Questions

None. Design covers all connection types and all 20 interface methods.
