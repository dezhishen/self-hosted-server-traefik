package core

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

type ConfigManager struct {
	loader contracts.AppConfigLoader
	path   string
}

func NewConfigManager(loader contracts.AppConfigLoader, path string) *ConfigManager {
	return &ConfigManager{loader: loader, path: path}
}

// LoadOrInit loads config or creates one with defaults.
func (m *ConfigManager) LoadOrInit() (*contracts.AppConfig, error) {
	if m.path == "" {
		def, err := m.loader.DefaultPath()
		if err != nil {
			return nil, fmt.Errorf("default config path: %w", err)
		}
		m.path = def
	}

	cfg, err := m.loader.Load(m.path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			cfg = m.defaultConfig()
			if err := m.loader.Save(cfg, m.path); err != nil {
				return nil, fmt.Errorf("save default config: %w", err)
			}
			return cfg, nil
		}
		return nil, fmt.Errorf("load config: %w", err)
	}

	if cfg.BaseDataDir == "" {
		cfg.BaseDataDir = m.defaultBaseDir()
		cfg.Endpoints = m.ensureDefaultEndpoint(cfg.Endpoints)
	}

	return cfg, nil
}

func (m *ConfigManager) defaultConfig() *contracts.AppConfig {
	return &contracts.AppConfig{
		BaseDataDir: m.defaultBaseDir(),
		Endpoints: map[string]*contracts.EndpointConfig{
			"default": {
				Name: "default",
				Connection: &contracts.ConnectionConfig{
					Type:     contracts.ConnectionTypeUnix,
					Endpoint: "/var/run/docker.sock",
				},
				Default: true,
			},
		},
	}
}

func (m *ConfigManager) defaultBaseDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "/var/lib/selfhosted"
	}
	return filepath.Join(home, ".local", "share", "selfhosted")
}

func (m *ConfigManager) ensureDefaultEndpoint(endpoints map[string]*contracts.EndpointConfig) map[string]*contracts.EndpointConfig {
	if endpoints == nil {
		endpoints = make(map[string]*contracts.EndpointConfig)
	}
	hasDefault := false
	for _, ep := range endpoints {
		if ep.Default {
			hasDefault = true
			break
		}
	}
	if !hasDefault {
		endpoints["default"] = &contracts.EndpointConfig{
			Name: "default",
			Connection: &contracts.ConnectionConfig{
				Type:     contracts.ConnectionTypeUnix,
				Endpoint: "/var/run/docker.sock",
			},
			Default: true,
		}
	}
	return endpoints
}

// EnsureDirs creates the directory structure for runtime data.
func EnsureDirs(baseDataDir string) error {
	dirs := []string{
		baseDataDir,
		filepath.Join(baseDataDir, "logs"),
		filepath.Join(baseDataDir, "config"),
		filepath.Join(baseDataDir, "args"),
	}
	for _, d := range dirs {
		if err := os.MkdirAll(d, 0755); err != nil {
			return fmt.Errorf("create dir %s: %w", d, err)
		}
	}
	return nil
}


