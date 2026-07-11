package core

import (
	"fmt"
	"path/filepath"

	"go.uber.org/zap"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"github.com/dezhishen/self-hosted-server-traefik/backend/config"
	"github.com/dezhishen/self-hosted-server-traefik/backend/endpoint"
	"github.com/dezhishen/self-hosted-server-traefik/backend/service"
	"github.com/dezhishen/self-hosted-server-traefik/backend/subscription"
	"github.com/dezhishen/self-hosted-server-traefik/backend/template"
)

type App struct {
	Config    *contracts.AppConfig
	ConfigMgr *ConfigManager
	Logger    *zap.Logger

	// Default endpoint name
	DefaultEndpoint string

	// Endpoint contexts keyed by endpoint name
	Endpoints map[string]*endpoint.Context

	// Shared services (not per-endpoint)
	TemplateEngine     contracts.TemplateEngine
	ServiceLoader      contracts.ServiceLoader
	ServiceValidator   contracts.ServiceValidator
	subMgr             contracts.SubscriptionManager
}

// initEndpointContext creates a single endpoint context from config.
// Extracted into a method so it can be reused when refreshing endpoints after config changes.
func (a *App) initEndpointContext(name string, epCfg *contracts.EndpointConfig) (*endpoint.Context, error) {
	runtime, err := endpoint.CreateRuntime(*epCfg.Connection, a.Config.BaseDataDir)
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
			a.Logger.Warn("endpoint has no connection config, skipping", zap.String("name", name))
			continue
		}
		ctx, err := a.initEndpointContext(name, epCfg)
		if err != nil {
			a.Logger.Warn("failed to refresh endpoint context", zap.String("name", name), zap.Error(err))
			continue
		}
		newEndpoints[name] = ctx

		a.Logger.Info("endpoint refreshed",
			zap.String("name", name),
			zap.Any("connection", epCfg.Connection),
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

func NewApp(configPath string) (*App, error) {
	// 1. Init logger (temporary dir until config is loaded)
	tmpLogger := zap.NewNop()

	// 2. Load config
	cfgMgr := NewConfigManager(config.NewLoader(), configPath)
	cfg, err := cfgMgr.LoadOrInit()
	if err != nil {
		return nil, fmt.Errorf("load config: %w", err)
	}

	// 3. Init logger with real base dir
	logger := InitLogger(cfg.BaseDataDir)

	// 4. Ensure directory structure
	if err := EnsureDirs(cfg.BaseDataDir); err != nil {
		logger.Warn("failed to create directories", zap.Error(err))
	}

	logger.Info("config loaded",
		zap.String("base_data_dir", cfg.BaseDataDir),
		zap.Int("endpoints", len(cfg.Endpoints)),
	)

	// 5. Create shared services
	tmpl := template.NewEngine()

	subPaths := []string{"templates/services"}
	svcLoader := service.NewLoader(subPaths)
	svcValidator := service.NewValidator()

	// 5b. Create subscription manager
	subStore := subscription.NewFileStore(filepath.Join(cfg.BaseDataDir, "config", "subscriptions.json"))
	subMgr := subscription.NewManager(subStore, cfg.BaseDataDir, logger)

	_ = tmpLogger

	// 6. Create App with shared services (needed before endpoint init)
	app := &App{
		Config:           cfg,
		ConfigMgr:        cfgMgr,
		Logger:           logger,
		TemplateEngine:   tmpl,
		ServiceLoader:    svcLoader,
		ServiceValidator: svcValidator,
		subMgr:           subMgr,
		Endpoints:        make(map[string]*endpoint.Context, len(cfg.Endpoints)),
	}

	// 7. Initialize endpoint contexts
	var defaultEp string
	for name, epCfg := range cfg.Endpoints {
		if epCfg.Default {
			defaultEp = name
		}
		if epCfg.Connection == nil {
			logger.Warn("endpoint has no connection config, skipping", zap.String("name", name))
			continue
		}
		ctx, err := app.initEndpointContext(name, epCfg)
		if err != nil {
			logger.Warn("failed to create runtime for endpoint",
				zap.String("name", name),
				zap.Error(err),
			)
			continue
		}
		app.Endpoints[name] = ctx

		logger.Info("endpoint initialized",
			zap.String("name", name),
			zap.Any("connection", epCfg.Connection),
		)
	}

	if len(app.Endpoints) == 0 {
		logger.Warn("no valid endpoints configured - server will start without runtime access")
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

func (a *App) SubscriptionManager() contracts.SubscriptionManager {
	return a.subMgr
}

func (a *App) Close() {
	for _, ctx := range a.Endpoints {
		if closer, ok := ctx.Runtime.(interface{ Close() }); ok {
			closer.Close()
		}
	}
	if a.Logger != nil {
		a.Logger.Sync()
	}
}
