package endpoint

import (
	"path/filepath"

	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
	"github.com/dezhishen/self-hosted-server-traefik/backend/store"
	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

type Context struct {
	Name    string
	Config  *contracts.EndpointConfig
	Runtime contracts.ContainerRuntime

	// Endpoint-scoped services
	ServiceManager contracts.ServiceManager
	MigrateService contracts.MigrateService
	ParamStore     contracts.ParamStore
	Logger         logger.Logger
}

type ContextOpts struct {
	Name           string
	Config         *contracts.EndpointConfig
	Runtime        contracts.ContainerRuntime
	BaseDataDir    string
	ServiceLoader  contracts.ServiceLoader
	TemplateEngine contracts.TemplateEngine
	Logger         logger.Logger
}

func NewContext(opts ContextOpts) *Context {
	argsDir := filepath.Join(opts.BaseDataDir, "endpoints", opts.Name, "args")

	paramStore := store.NewArgsStore(argsDir)

	svcMgr := NewServiceManager(ServiceManagerOpts{
		Runtime:        opts.Runtime,
		ParamStore:     paramStore,
		ServiceLoader:  opts.ServiceLoader,
		TemplateEngine: opts.TemplateEngine,
		Logger:         opts.Logger,
		Name:           opts.Name,
	})

	generatedDir := filepath.Join(opts.BaseDataDir, "templates", "generated")

	migrateSvc := NewMigrateService(
		opts.Runtime,
		opts.ServiceLoader,
		svcMgr,
		opts.Logger,
		opts.Name,
		generatedDir,
	)

	return &Context{
		Name:           opts.Name,
		Config:         opts.Config,
		Runtime:        opts.Runtime,
		ServiceManager: svcMgr,
		MigrateService: migrateSvc,
		ParamStore:     paramStore,
		Logger:         opts.Logger,
	}
}
