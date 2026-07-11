package config

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/spf13/viper"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time check: *Loader implements contracts.AppConfigLoader.
var _ contracts.AppConfigLoader = (*Loader)(nil)

// Loader implements contracts.AppConfigLoader using viper.
// Config is stored in a directory as system.yaml + endpoints.yaml.
type Loader struct {
	migratedPath string // set after Load() migrates from old file format
}

func NewLoader() *Loader {
	return &Loader{}
}

// MigratedPath returns the new directory path if a migration occurred during Load().
func (l *Loader) MigratedPath() string {
	return l.migratedPath
}

// DefaultPath returns the default config directory path.
func (l *Loader) DefaultPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".config", "selfhosted"), nil
}

// Load reads config from path. If path is a directory, reads system.yaml + endpoints.yaml.
// If path is a file (old format), migrates to directory format automatically.
func (l *Loader) Load(path string) (*contracts.AppConfig, error) {
	info, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, err
		}
		return nil, fmt.Errorf("stat config path: %w", err)
	}

	if info.IsDir() {
		return l.loadDir(path)
	}

	// Old format: single file
	cfg, err := l.loadOldFile(path)
	if err != nil {
		return nil, err
	}

	// Auto-migrate to directory format
	newDir, err := l.migrateToDir(path, cfg)
	if err != nil {
		log.Printf("WARN: failed to migrate config to directory format: %v (continuing with old format)", err)
		return cfg, nil
	}
	l.migratedPath = newDir
	log.Printf("Config migrated from %s to %s/ (directory format)", path, newDir)
	return cfg, nil
}

// loadOldFile reads a single YAML file (legacy format) using viper.
func (l *Loader) loadOldFile(path string) (*contracts.AppConfig, error) {
	v := viper.New()
	v.SetConfigFile(path)
	v.SetConfigType("yaml")
	if err := v.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}
	var cfg contracts.AppConfig
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	return &cfg, nil
}

// loadDir reads system.yaml and endpoints.yaml from a config directory using viper.
func (l *Loader) loadDir(dir string) (*contracts.AppConfig, error) {
	cfg := &contracts.AppConfig{}

	// Read system.yaml
	sys, err := l.readSystemYAML(dir)
	if err != nil {
		return nil, err
	}
	if sys != nil {
		cfg.BaseDataDir = sys.BaseDataDir
		cfg.Auth = sys.Auth
	}

	// Read endpoints.yaml
	eps, err := l.readEndpointsYAML(dir)
	if err != nil {
		return nil, err
	}
	if eps != nil {
		cfg.Endpoints = eps.Endpoints
	}

	return cfg, nil
}

// readSystemYAML loads system.yaml using viper.
// Returns nil if file doesn't exist (not an error — file is optional).
func (l *Loader) readSystemYAML(dir string) (*contracts.SystemConfig, error) {
	cfgDir := filepath.Join(dir, "config")
	v := viper.New()
	v.AddConfigPath(cfgDir)
	v.SetConfigName("system")
	v.SetConfigType("yaml")

	if err := v.ReadInConfig(); err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("read system.yaml: %w", err)
	}

	var sys contracts.SystemConfig
	if err := v.Unmarshal(&sys); err != nil {
		return nil, fmt.Errorf("parse system.yaml: %w", err)
	}
	return &sys, nil
}

// readEndpointsYAML loads endpoints.yaml using viper.
// Returns nil if file doesn't exist (not an error — file is optional).
func (l *Loader) readEndpointsYAML(dir string) (*contracts.EndpointCollection, error) {
	cfgDir := filepath.Join(dir, "config")
	v := viper.New()
	v.AddConfigPath(cfgDir)
	v.SetConfigName("endpoints")
	v.SetConfigType("yaml")

	if err := v.ReadInConfig(); err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("read endpoints.yaml: %w", err)
	}

	var eps contracts.EndpointCollection
	if err := v.Unmarshal(&eps); err != nil {
		return nil, fmt.Errorf("parse endpoints.yaml: %w", err)
	}
	return &eps, nil
}

// Save writes config to path. If path is a directory, uses split-file format.
// If path is a file, uses old single-file format (backward compat).
func (l *Loader) Save(config *contracts.AppConfig, path string) error {
	info, err := os.Stat(path)
	if err == nil && info.IsDir() {
		return l.saveDir(config, path)
	}

	// File doesn't exist or is a file — check if config dir style
	ext := filepath.Ext(path)
	if ext != ".yaml" && ext != ".yml" {
		if err := os.MkdirAll(path, 0755); err != nil {
			return fmt.Errorf("create config dir: %w", err)
		}
		return l.saveDir(config, path)
	}

	// Old format: single file
	return l.saveFile(config, path)
}

// saveFile writes config as a single YAML file (legacy format) using viper.
func (l *Loader) saveFile(config *contracts.AppConfig, path string) error {
	v := viper.New()
	v.SetConfigFile(path)
	v.SetConfigType("yaml")

	v.Set("base_data_dir", config.BaseDataDir)
	if config.Auth != nil {
		v.Set("auth", config.Auth)
	}
	v.Set("endpoints", config.Endpoints)
	v.Set("subscriptions", config.Subscriptions)

	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}
	if err := v.WriteConfig(); err != nil {
		return fmt.Errorf("write config: %w", err)
	}
	return nil
}

// saveDir writes system.yaml and endpoints.yaml using viper.
func (l *Loader) saveDir(config *contracts.AppConfig, dir string) error {
	cfgDir := filepath.Join(dir, "config")
	if err := os.MkdirAll(cfgDir, 0755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}

	// Write system.yaml
	sysViper := viper.New()
	sysViper.AddConfigPath(cfgDir)
	sysViper.SetConfigName("system")
	sysViper.SetConfigType("yaml")

	sysViper.Set("base_data_dir", config.BaseDataDir)
	if config.Auth != nil {
		sysViper.Set("auth", config.Auth)
	}
	if err := sysViper.SafeWriteConfig(); err != nil {
		// If file already exists, use WriteConfig (overwrite)
		if _, ok := err.(viper.ConfigFileAlreadyExistsError); ok {
			if err := sysViper.WriteConfig(); err != nil {
				return fmt.Errorf("write system.yaml: %w", err)
			}
		} else {
			return fmt.Errorf("write system.yaml: %w", err)
		}
	}

	// Write endpoints.yaml
	epViper := viper.New()
	epViper.AddConfigPath(cfgDir)
	epViper.SetConfigName("endpoints")
	epViper.SetConfigType("yaml")

	eps := contracts.EndpointCollection{
		Endpoints: config.Endpoints,
	}
	epViper.Set("endpoints", eps.Endpoints)
	if err := epViper.SafeWriteConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileAlreadyExistsError); ok {
			if err := epViper.WriteConfig(); err != nil {
				return fmt.Errorf("write endpoints.yaml: %w", err)
			}
		} else {
			return fmt.Errorf("write endpoints.yaml: %w", err)
		}
	}

	return nil
}

// migrateToDir migrates from old single-file format to new directory format.
func (l *Loader) migrateToDir(oldPath string, cfg *contracts.AppConfig) (string, error) {
	newDir := oldPath + ".d"

	if err := os.MkdirAll(newDir, 0755); err != nil {
		return "", fmt.Errorf("create config dir %s: %w", newDir, err)
	}

	if err := l.saveDir(cfg, newDir); err != nil {
		return "", fmt.Errorf("write split configs: %w", err)
	}

	backupPath := oldPath + ".migrated"
	if err := os.Rename(oldPath, backupPath); err != nil {
		return "", fmt.Errorf("backup old config: %w", err)
	}

	return newDir, nil
}
