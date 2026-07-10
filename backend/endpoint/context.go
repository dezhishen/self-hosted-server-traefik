package endpoint

import (
	"path/filepath"

	"go.uber.org/zap"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"github.com/dezhishen/self-hosted-server-traefik/backend/store"
)

type Context struct {
	Name    string
	Config  *contracts.EndpointConfig
	Runtime contracts.ContainerRuntime

	// Endpoint-scoped services
	ServiceManager contracts.ServiceManager
	ParamStore     contracts.ParamStore
	Logger         *zap.Logger
}

type ContextOpts struct {
	Name           string
	Config         *contracts.EndpointConfig
	Runtime        contracts.ContainerRuntime
	BaseDataDir    string
	ServiceLoader  contracts.ServiceLoader
	TemplateEngine contracts.TemplateEngine
	Logger         *zap.Logger
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

	return &Context{
		Name:           opts.Name,
		Config:         opts.Config,
		Runtime:        opts.Runtime,
		ServiceManager: svcMgr,
		ParamStore:     paramStore,
		Logger:         opts.Logger,
	}
}
