package contracts_test

import (
	"testing"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

func TestConnectionTypeConstants(t *testing.T) {
	if contracts.ConnectionTypeUnix != "unix" {
		t.Error("ConnectionTypeUnix should be 'unix'")
	}
	if contracts.ConnectionTypeTCP != "tcp" {
		t.Error("ConnectionTypeTCP should be 'tcp'")
	}
	if contracts.ConnectionTypeSSH != "ssh" {
		t.Error("ConnectionTypeSSH should be 'ssh'")
	}
}

func TestEngineTypeConstants(t *testing.T) {
	if contracts.EngineTypeDocker != "docker" {
		t.Error("EngineTypeDocker should be 'docker'")
	}
	if contracts.EngineTypePodman != "podman" {
		t.Error("EngineTypePodman should be 'podman'")
	}
	if contracts.EngineTypeAuto != "auto" {
		t.Error("EngineTypeAuto should be 'auto'")
	}
}

func TestParamTypeConstants(t *testing.T) {
	if contracts.ParamTypeString != "string" {
		t.Error("ParamTypeString should be 'string'")
	}
	if contracts.ParamTypePassword != "password" {
		t.Error("ParamTypePassword should be 'password'")
	}
	if contracts.ParamTypeBool != "bool" {
		t.Error("ParamTypeBool should be 'bool'")
	}
	if contracts.ParamTypeNumber != "number" {
		t.Error("ParamTypeNumber should be 'number'")
	}
	if contracts.ParamTypeSelect != "select" {
		t.Error("ParamTypeSelect should be 'select'")
	}
	if contracts.ParamTypeArray != "array" {
		t.Error("ParamTypeArray should be 'array'")
	}
}

func TestRestartPolicyConstants(t *testing.T) {
	if contracts.RestartPolicyNo != "no" {
		t.Error("RestartPolicyNo should be 'no'")
	}
	if contracts.RestartPolicyAlways != "always" {
		t.Error("RestartPolicyAlways should be 'always'")
	}
	if contracts.RestartPolicyOnFailure != "on-failure" {
		t.Error("RestartPolicyOnFailure should be 'on-failure'")
	}
	if contracts.RestartPolicyUnlessStopped != "unless-stopped" {
		t.Error("RestartPolicyUnlessStopped should be 'unless-stopped'")
	}
}

func TestNetworkDriverConstants(t *testing.T) {
	if contracts.NetworkDriverBridge != "bridge" {
		t.Error("NetworkDriverBridge should be 'bridge'")
	}
	if contracts.NetworkDriverHost != "host" {
		t.Error("NetworkDriverHost should be 'host'")
	}
	if contracts.NetworkDriverNone != "none" {
		t.Error("NetworkDriverNone should be 'none'")
	}
}

func TestServiceStatusConstants(t *testing.T) {
	if contracts.ServiceStatusInstalled != "installed" {
		t.Error("ServiceStatusInstalled should be 'installed'")
	}
	if contracts.ServiceStatusRunning != "running" {
		t.Error("ServiceStatusRunning should be 'running'")
	}
	if contracts.ServiceStatusStopped != "stopped" {
		t.Error("ServiceStatusStopped should be 'stopped'")
	}
}

func TestRenderModeConstants(t *testing.T) {
	if contracts.RenderPlain != "plain" {
		t.Error("RenderPlain should be 'plain'")
	}
	if contracts.RenderEnv != "env" {
		t.Error("RenderEnv should be 'env'")
	}
	if contracts.RenderJSON != "json" {
		t.Error("RenderJSON should be 'json'")
	}
}

func TestManagedLabels(t *testing.T) {
	labels := contracts.ManagedLabels("traefik", "v1", "local", "docker")
	if labels[contracts.ManagedLabelKey] != "true" {
		t.Error("ManagedLabelKey should be 'true'")
	}
	if labels[contracts.ManagedServiceLabel] != "traefik" {
		t.Error("ManagedServiceLabel should be 'traefik'")
	}
	if labels[contracts.ManagedHostLabel] != "local" {
		t.Error("ManagedHostLabel should be 'local'")
	}
	if labels[contracts.ManagedEngineLabel] != "docker" {
		t.Error("ManagedEngineLabel should be 'docker'")
	}
}

func TestAppConfig(t *testing.T) {
	cfg := contracts.AppConfig{
		BaseDataDir: "/data",
		Endpoints: map[string]*contracts.EndpointConfig{
			"local": {Name: "local", Default: true},
		},
	}
	if cfg.BaseDataDir != "/data" {
		t.Errorf("BaseDataDir = %q", cfg.BaseDataDir)
	}
	if len(cfg.Endpoints) != 1 {
		t.Errorf("expected 1 endpoint, got %d", len(cfg.Endpoints))
	}
}

func TestServiceStatusResult(t *testing.T) {
	r := contracts.ServiceStatusResult{
		Name:   "traefik",
		Status: contracts.ServiceStatusRunning,
	}
	if r.Name != "traefik" {
		t.Errorf("ServiceStatusResult.Name = %q", r.Name)
	}
	if r.Status != contracts.ServiceStatusRunning {
		t.Errorf("ServiceStatusResult.Status = %q", r.Status)
	}
}

func TestConnectionConfig(t *testing.T) {
	c := contracts.ConnectionConfig{
		Type:     contracts.ConnectionTypeUnix,
		Endpoint: "/var/run/docker.sock",
	}
	if c.Endpoint != "/var/run/docker.sock" {
		t.Errorf("ConnectionConfig.Endpoint = %q", c.Endpoint)
	}
}
