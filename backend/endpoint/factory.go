package endpoint

import (
	"fmt"
	"os/exec"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	dockerAdapter "github.com/dezhishen/self-hosted-server-traefik/backend/adapter/docker"
	podmanAdapter "github.com/dezhishen/self-hosted-server-traefik/backend/adapter/podman"
)

// CreateRuntime creates a ContainerRuntime based on the connection config.
func CreateRuntime(cfg contracts.ConnectionConfig) (contracts.ContainerRuntime, error) {
	// Auto-detect: try docker first, then podman
	engine := cfg.Engine
	if engine == "" || engine == contracts.EngineTypeAuto {
		if _, err := exec.LookPath("docker"); err == nil {
			engine = contracts.EngineTypeDocker
		} else if _, err := exec.LookPath("podman"); err == nil {
			engine = contracts.EngineTypePodman
		} else {
			return nil, fmt.Errorf("no container runtime found (docker or podman)")
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
