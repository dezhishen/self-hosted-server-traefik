package core

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"github.com/dezhishen/self-hosted-server-traefik/backend/config"
	"github.com/dezhishen/self-hosted-server-traefik/backend/endpoint"
	"github.com/dezhishen/self-hosted-server-traefik/backend/service"
	"github.com/dezhishen/self-hosted-server-traefik/backend/apprepo"
	"github.com/dezhishen/self-hosted-server-traefik/backend/template"
)

type App struct {
	Config    *contracts.AppConfig
	ConfigMgr *ConfigManager
	Logger    logger.Logger

	// Default endpoint name
	DefaultEndpoint string

	// Endpoint contexts keyed by endpoint name
	Endpoints map[string]*endpoint.Context

	// SSH key manager (separate store from endpoints.yaml)
	SSHKeyManager *SSHKeyManager

	// Shared services (not per-endpoint)
	TemplateEngine     contracts.TemplateEngine
	ServiceLoader      contracts.ServiceLoader
	ServiceValidator   contracts.ServiceValidator
	subMgr             contracts.AppRepoManager
}

// initEndpointContext creates a single endpoint context from config.
// Extracted into a method so it can be reused when refreshing endpoints after config changes.
// Resolves SSH key references from the key store before creating the runtime.
func (a *App) initEndpointContext(name string, epCfg *contracts.EndpointConfig) (*endpoint.Context, error) {
	// Resolve SSH key reference: copy config and populate private key from key store
	connCfg := *epCfg.Connection
	if connCfg.SSHKeyRef != "" && a.SSHKeyManager != nil {
		if pk, ok := a.SSHKeyManager.GetPrivateKey(connCfg.SSHKeyRef); ok {
			connCfg.SSHPrivateKey = pk
		} else {
			return nil, fmt.Errorf("SSH key %q not found for endpoint %q", connCfg.SSHKeyRef, name)
		}
	}
	runtime, err := endpoint.CreateRuntime(connCfg, a.Config.BaseDataDir)
	if err != nil {
		return nil, err
	}
	return endpoint.NewContext(endpoint.ContextOpts{
		Name:           name,
		Config:         epCfg,
		Runtime:        runtime,
		BaseDataDir:    a.Config.BaseDataDir,
		ServiceLoader:  a.ServiceLoader,
		TemplateEngine: a.TemplateEngine,
		Logger:         a.Logger,
	}), nil
}

// RefreshEndpoints tears down and rebuilds all endpoint runtime contexts.
// Call after config changes (e.g. PUT /api/config) to pick up new connection
// settings (SSH keys, TLS certs, connection type, etc.) without restarting the server.
func (a *App) RefreshEndpoints() {
	// Close existing runtime connections
	for _, ctx := range a.Endpoints {
		if closer, ok := ctx.Runtime.(interface{ Close() }); ok {
			closer.Close()
		}
	}

	// Rebuild from current config
	newEndpoints := make(map[string]*endpoint.Context, len(a.Config.Endpoints))
	var defaultEp string
	for name, epCfg := range a.Config.Endpoints {
		if epCfg.Default {
			defaultEp = name
		}
		if epCfg.Connection == nil {
			a.Logger.Warn("endpoint has no connection config, skipping", logger.String("name", name))
			continue
		}
		ctx, err := a.initEndpointContext(name, epCfg)
		if err != nil {
			a.Logger.Warn("failed to refresh endpoint context", logger.String("name", name), logger.Error(err))
			continue
		}
		newEndpoints[name] = ctx

		a.Logger.Info("endpoint refreshed",
			logger.String("name", name),
			logger.Any("connection", epCfg.Connection),
		)
	}

	if len(newEndpoints) == 0 {
		a.Logger.Warn("no valid endpoints after refresh")
	}

	if defaultEp == "" {
		for name := range newEndpoints {
			defaultEp = name
			break
		}
	}

	a.Endpoints = newEndpoints
	a.DefaultEndpoint = defaultEp
}

// resolveAppsDir finds the apps/ directory, checking multiple locations
// since the CWD may not be the project root (e.g. make dev uses -C backend).
func resolveAppsDir(baseDataDir string) string {
	// 1. Check relative to CWD (works when running from project root)
	if _, err := os.Stat("apps/index.yaml"); err == nil {
		if abs, err := filepath.Abs("apps"); err == nil {
			return abs
		}
		return "apps"
	}
	// 2. Check parent of CWD (works when CWD = backend/)
	if _, err := os.Stat("../apps/index.yaml"); err == nil {
		if abs, err := filepath.Abs("../apps"); err == nil {
			return abs
		}
		return "../apps"
	}
	// 3. Check relative to base data dir (dev setup: baseDataDir = .selfhosted.dev, apps at project root)
	if baseDataDir != "" {
		candidate := filepath.Join(baseDataDir, "..", "apps")
		if _, err := os.Stat(filepath.Join(candidate, "index.yaml")); err == nil {
			if abs, err := filepath.Abs(candidate); err == nil {
				return abs
			}
			return candidate
		}
	}
	// 4. Fallback: return relative path, will be handled gracefully by LoadAll()
	return "apps"
}

func NewApp(configPath string) (*App, error) {
	// 1. Init logger (temporary dir until config is loaded)
	tmpLogger := logger.NewNop()

	// 2. Load config
	cfgMgr := NewConfigManager(config.NewLoader(), configPath)
	cfg, err := cfgMgr.LoadOrInit()
	if err != nil {
		return nil, fmt.Errorf("load config: %w", err)
	}

	// 3. Init logger with real base dir
	log := InitLogger(cfg.BaseDataDir)

	// 4. Ensure directory structure
	if err := EnsureDirs(cfg.BaseDataDir); err != nil {
		log.Warn("failed to create directories", logger.Error(err))
	}

	log.Info("config loaded",
		logger.String("base_data_dir", cfg.BaseDataDir),
		logger.Int("endpoints", len(cfg.Endpoints)),
	)

	// 5. Initialize SSH key manager (separate store from endpoints.yaml)
	keyStorePath := filepath.Join(cfg.BaseDataDir, "config", "ssh_keys.yaml")
	keyMgr := NewSSHKeyManager(keyStorePath)
	if err := keyMgr.Load(); err != nil {
		log.Warn("failed to load SSH keys", logger.Error(err))
	}

	// 5b. Migrate legacy endpoints that have SSHPrivateKey embedded
	migrated, err := keyMgr.MigrateFromEndpoints(cfg.Endpoints)
	if err != nil {
		log.Warn("failed to migrate legacy SSH keys", logger.Error(err))
	} else if migrated {
		log.Info("migrated legacy SSH keys to standalone key store")
		if err := cfgMgr.SaveEndpoints(cfg.Endpoints); err != nil {
			log.Warn("failed to save migrated endpoints", logger.Error(err))
		}
	}

	// 6. Create shared services
	tmpl := template.NewEngine()

	// Loader uses the apps/ directory which contains index.yaml
	// Resolve to absolute path since CWD may differ (e.g. make dev uses -C backend)
	appsDir := resolveAppsDir(cfg.BaseDataDir)
	log.Info("resolved apps directory", logger.String("dir", appsDir))
	svcLoader := service.NewLoader([]string{appsDir})
	svcValidator := service.NewValidator()

	// 5b. Create subscription manager
	subStore := apprepo.NewFileStore(filepath.Join(cfg.BaseDataDir, "config", "subscriptions.json"))
	subMgr := apprepo.NewManager(subStore, cfg.BaseDataDir, log)

	// Development convenience: detect local templates/ dir and use it as default
	if localIndex := "apps/index.yaml"; len(apprepo.DefaultSubscriptions) > 0 {
		if absPath, err := filepath.Abs(localIndex); err == nil {
			if _, err := os.Stat(absPath); err == nil {
				apprepo.DefaultSubscriptions[0].URL = absPath
				apprepo.DefaultSubscriptions[0].Description = "Local service templates (development)"
			}
		}
	}

	// Seed default subscriptions and register their template directories
	if err := subMgr.SeedDefaults(); err != nil {
		log.Warn("failed to seed default subscriptions", logger.Error(err))
	}
	// Add synced subscription template directories to the service loader
	// Each subscription caches its index.yaml and templates under {baseDir}/templates/{name}/
	subs, _ := subMgr.List()
	for _, sub := range subs {
		subTmplDir := filepath.Join(cfg.BaseDataDir, "apps", sub.Name)
		if _, err := os.Stat(filepath.Join(subTmplDir, "index.yaml")); err == nil {
			svcLoader.AddPath(subTmplDir)
		}
	}

	_ = tmpLogger

	// 7. Create App with shared services (needed before endpoint init)
	app := &App{
		Config:           cfg,
		ConfigMgr:        cfgMgr,
		Logger:           log,
		SSHKeyManager:    keyMgr,
		TemplateEngine:   tmpl,
		ServiceLoader:    svcLoader,
		ServiceValidator: svcValidator,
		subMgr:           subMgr,
		Endpoints:        make(map[string]*endpoint.Context, len(cfg.Endpoints)),
	}

	// 8. Initialize endpoint contexts
	var defaultEp string
	for name, epCfg := range cfg.Endpoints {
		if epCfg.Default {
			defaultEp = name
		}
		if epCfg.Connection == nil {
			log.Warn("endpoint has no connection config, skipping", logger.String("name", name))
			continue
		}
		ctx, err := app.initEndpointContext(name, epCfg)
		if err != nil {
			log.Warn("failed to create runtime for endpoint",
				logger.String("name", name),
				logger.Error(err),
			)
			continue
		}
		app.Endpoints[name] = ctx

		log.Info("endpoint initialized",
			logger.String("name", name),
			logger.Any("connection", epCfg.Connection),
		)
	}

	if len(app.Endpoints) == 0 {
		log.Warn("no valid endpoints configured - server will start without runtime access")
	}

	if defaultEp == "" {
		for name := range app.Endpoints {
			defaultEp = name
			break
		}
	}
	app.DefaultEndpoint = defaultEp

	return app, nil
}

func (a *App) GetEndpoint(name string) (*endpoint.Context, bool) {
	ctx, ok := a.Endpoints[name]
	return ctx, ok
}

func (a *App) GetDefaultEndpoint() *endpoint.Context {
	return a.Endpoints[a.DefaultEndpoint]
}

func (a *App) AppRepoManager() contracts.AppRepoManager {
	return a.subMgr
}

func (a *App) Close() {
	for _, ctx := range a.Endpoints {
		if closer, ok := ctx.Runtime.(interface{ Close() }); ok {
			closer.Close()
		}
	}
	if a.Logger != nil {
		_ = a.Logger.Sync()
	}
}
