package endpoint

import (
	"fmt"
	"net"
	"time"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	dockerAdapter "github.com/dezhishen/self-hosted-server-traefik/backend/adapter/docker"
	podmanAdapter "github.com/dezhishen/self-hosted-server-traefik/backend/adapter/podman"
)

// Default socket paths for engine detection.
const (
	dockerSocketPath = "/var/run/docker.sock"
	podmanSocketPath = "/run/podman/podman.sock"
)

// CreateRuntime creates a ContainerRuntime based on the connection config.
func CreateRuntime(cfg contracts.ConnectionConfig, baseDataDir string) (contracts.ContainerRuntime, error) {
	// Auto-detect: try Docker socket first, then Podman socket
	engine := cfg.Engine
	if engine == "" || engine == contracts.EngineTypeAuto {
		if detectSocket(dockerSocketPath) {
			engine = contracts.EngineTypeDocker
		} else if detectSocket(podmanSocketPath) {
			engine = contracts.EngineTypePodman
		} else {
			return nil, fmt.Errorf("no container runtime found (tried %s and %s)", dockerSocketPath, podmanSocketPath)
		}
	}

	switch engine {
	case contracts.EngineTypeDocker:
		return dockerAdapter.NewRuntime(cfg)
	case contracts.EngineTypePodman:
		return podmanAdapter.NewRuntime(cfg)
	default:
		return nil, fmt.Errorf("unsupported engine: %s", engine)
	}
}

// detectSocket attempts to connect to a Unix socket to check if it's listening.
// Uses a short timeout to avoid hanging.
func detectSocket(path string) bool {
	conn, err := net.DialTimeout("unix", path, 2*time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}
