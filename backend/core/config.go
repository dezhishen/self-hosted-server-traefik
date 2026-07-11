package core

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"gopkg.in/yaml.v3"
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
			if err := m.ensureDir(); err != nil {
				return nil, fmt.Errorf("ensure config dir: %w", err)
			}
			if err := m.loader.Save(cfg, m.path); err != nil {
				return nil, fmt.Errorf("save default config: %w", err)
			}
			return cfg, nil
		}
		return nil, fmt.Errorf("load config: %w", err)
	}

	// Check if loader migrated from old file format to directory
	if migrator, ok := m.loader.(interface{ MigratedPath() string }); ok {
		if newPath := migrator.MigratedPath(); newPath != "" {
			m.path = newPath
		}
	}

	if cfg.BaseDataDir == "" {
		cfg.BaseDataDir = m.path // config root IS the data root
		cfg.Endpoints = m.ensureDefaultEndpoint(cfg.Endpoints)
	}

	return cfg, nil
}

// ensureDir creates the config directory if it doesn't exist.
func (m *ConfigManager) ensureDir() error {
	return os.MkdirAll(m.path, 0755)
}

func (m *ConfigManager) defaultConfig() *contracts.AppConfig {
	return &contracts.AppConfig{
		BaseDataDir: m.path,
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

func (m *ConfigManager) Path() string {
	return m.path
}

func (m *ConfigManager) Save(cfg *contracts.AppConfig) error {
	return m.loader.Save(cfg, m.path)
}

// SaveEndpoints saves only the endpoints.yaml file. Never touches system.yaml.
func (m *ConfigManager) SaveEndpoints(eps map[string]*contracts.EndpointConfig) error {
	epPath := filepath.Join(m.path, "config", "endpoints.yaml")
	collection := contracts.EndpointCollection{Endpoints: eps}
	data, err := yaml.Marshal(collection)
	if err != nil {
		return fmt.Errorf("marshal endpoints: %w", err)
	}
	return os.WriteFile(epPath, data, 0644)
}

// SaveSystem saves only the system.yaml file.
func (m *ConfigManager) SaveSystem(baseDataDir string, auth *contracts.AuthConfig) error {
	sysPath := filepath.Join(m.path, "config", "system.yaml")
	sys := contracts.SystemConfig{BaseDataDir: baseDataDir, Auth: auth}
	data, err := yaml.Marshal(sys)
	if err != nil {
		return fmt.Errorf("marshal system config: %w", err)
	}
	return os.WriteFile(sysPath, data, 0644)
}

// SavePut handles PUT /api/config safely.
// It only writes endpoints.yaml. System settings (base_data_dir, auth) are
// merged in-memory but never persisted via this path, with two exceptions:
//   - auth.username is saved if the incoming request provides a non-empty value
//   - password_hash is ALWAYS preserved from the existing config on disk
func (m *ConfigManager) SavePut(cfg *contracts.AppConfig) error {
	// 1. Load the existing system config from disk to preserve password_hash
	existingSys := m.loadSystemFromDisk()

	// 2. Build merged system config
	mergedBaseDir := existingSys.BaseDataDir
	if mergedBaseDir == "" {
		mergedBaseDir = m.path
	}

	mergedAuth := &contracts.AuthConfig{}
	if existingSys.Auth != nil {
		mergedAuth.PasswordHash = existingSys.Auth.PasswordHash // always preserved
		mergedAuth.Username = existingSys.Auth.Username
	}
	if cfg.Auth != nil && cfg.Auth.Username != "" {
		mergedAuth.Username = cfg.Auth.Username // apply username change
	}

	// 3. Save endpoints (always overwrite)
	if err := m.SaveEndpoints(cfg.Endpoints); err != nil {
		return err
	}

	// 4. Save system if there's meaningful data
	if mergedBaseDir != "" || mergedAuth.Username != "" || mergedAuth.PasswordHash != "" {
		if err := m.SaveSystem(mergedBaseDir, mergedAuth); err != nil {
			return err
		}
	}

	return nil
}

// loadSystemFromDisk reads the current system.yaml from disk.
// Returns empty SystemConfig if file doesn't exist or can't be read.
func (m *ConfigManager) loadSystemFromDisk() *contracts.SystemConfig {
	sysPath := filepath.Join(m.path, "config", "system.yaml")
	data, err := os.ReadFile(sysPath)
	if err != nil {
		return &contracts.SystemConfig{}
	}
	var sys contracts.SystemConfig
	if err := yaml.Unmarshal(data, &sys); err != nil {
		return &contracts.SystemConfig{}
	}
	return &sys
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


