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

	// 6. Create endpoint contexts
	endpointCtxs := make(map[string]*endpoint.Context, len(cfg.Endpoints))
	var defaultEp string
	for name, epCfg := range cfg.Endpoints {
		if epCfg.Default {
			defaultEp = name
		}

		if epCfg.Connection == nil {
			logger.Warn("endpoint has no connection config, skipping", zap.String("name", name))
			continue
		}

		// Create runtime adapter
		runtime, err := endpoint.CreateRuntime(*epCfg.Connection)
		if err != nil {
			logger.Warn("failed to create runtime for endpoint",
				zap.String("name", name),
				zap.Error(err),
			)
			continue
		}

		ctx := endpoint.NewContext(endpoint.ContextOpts{
			Name:           name,
			Config:         epCfg,
			Runtime:        runtime,
			BaseDataDir:    cfg.BaseDataDir,
			ServiceLoader:  svcLoader,
			TemplateEngine: tmpl,
			Logger:         logger,
		})
		endpointCtxs[name] = ctx

		logger.Info("endpoint initialized",
			zap.String("name", name),
			zap.Any("connection", epCfg.Connection),
		)
	}

	if len(endpointCtxs) == 0 {
		logger.Warn("no valid endpoints configured - server will start without runtime access")
	}

	if defaultEp == "" {
		for name := range endpointCtxs {
			defaultEp = name
			break
		}
	}

	return &App{
		Config:           cfg,
		ConfigMgr:        cfgMgr,
		Logger:           logger,
		DefaultEndpoint:  defaultEp,
		Endpoints:        endpointCtxs,
		TemplateEngine:     tmpl,
		ServiceLoader:      svcLoader,
		ServiceValidator:   svcValidator,
		subMgr:             subMgr,
	}, nil
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
	if a.Logger != nil {
		a.Logger.Sync()
	}
}
