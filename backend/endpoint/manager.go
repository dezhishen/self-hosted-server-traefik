package endpoint

import (
	"fmt"

	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time check: *serviceManager implements contracts.ServiceManager.
var _ contracts.ServiceManager = (*serviceManager)(nil)

// ServiceManagerOpts configures an endpoint-scoped ServiceManager.
type ServiceManagerOpts struct {
	Runtime        contracts.ContainerRuntime
	ParamStore     contracts.ParamStore
	ServiceLoader  contracts.ServiceLoader
	TemplateEngine contracts.TemplateEngine
	Logger         logger.Logger
	Name           string
	Endpoint       *contracts.EndpointConfig
}

type serviceManager struct {
	runtime        contracts.ContainerRuntime
	paramStore     contracts.ParamStore
	serviceLoader  contracts.ServiceLoader
	templateEngine contracts.TemplateEngine
	log            logger.Logger
	name           string
	endpoint       *contracts.EndpointConfig
}

// NewServiceManager creates a ServiceManager that operates within an endpoint scope.
func NewServiceManager(opts ServiceManagerOpts) contracts.ServiceManager {
	return &serviceManager{
		runtime:        opts.Runtime,
		paramStore:     opts.ParamStore,
		serviceLoader:  opts.ServiceLoader,
		templateEngine: opts.TemplateEngine,
		log:            opts.Logger,
		name:           opts.Name,
		endpoint:       opts.Endpoint,
	}
}

func (m *serviceManager) List() ([]*contracts.ServiceDefinition, error) {
	return m.serviceLoader.LoadAll()
}

func (m *serviceManager) ListInstalled() ([]*contracts.ServiceDefinition, error) {
	all, err := m.serviceLoader.LoadAll()
	if err != nil {
		return nil, err
	}
	var result []*contracts.ServiceDefinition
	for _, svc := range all {
		status, _ := m.Status(svc.Name)
		if status != nil && status.Status != contracts.ServiceStatusNotInstalled {
			result = append(result, svc)
		}
	}
	return result, nil
}

func (m *serviceManager) Get(name string) (*contracts.ServiceDefinition, error) {
	return m.serviceLoader.Load(name)
}

func (m *serviceManager) GetByCategory(category string) ([]*contracts.ServiceDefinition, error) {
	all, err := m.serviceLoader.LoadAll()
	if err != nil {
		return nil, err
	}
	var result []*contracts.ServiceDefinition
	for _, svc := range all {
		if svc.Category == category {
			result = append(result, svc)
		}
	}
	if result == nil {
		result = []*contracts.ServiceDefinition{}
	}
	return result, nil
}

func (m *serviceManager) Search(query string) ([]*contracts.ServiceDefinition, error) {
	all, err := m.serviceLoader.LoadAll()
	if err != nil {
		return nil, err
	}
	var result []*contracts.ServiceDefinition
	for _, svc := range all {
		if contains(svc.Name, query) || contains(svc.Description, query) {
			result = append(result, svc)
		}
	}
	if result == nil {
		result = []*contracts.ServiceDefinition{}
	}
	return result, nil
}

func (m *serviceManager) Install(name string, params []*contracts.ParamValue, remote string) (string, error) {
	svc, err := m.serviceLoader.Load(name)
	if err != nil {
		return "", fmt.Errorf("load service: %w", err)
	}

	// Save params
	for _, p := range params {
		if err := m.paramStore.Set(p); err != nil {
			return "", fmt.Errorf("save param %s: %w", p.Name, err)
		}
	}

	// Build container run params
	runParams, err := m.buildRunParams(svc, params)
	if err != nil {
		return "", fmt.Errorf("build run params: %w", err)
	}

	// Pull image
	m.log.Info("pulling image", logger.String("image", runParams.Image))
	if err := m.runtime.PullImage(runParams.Image); err != nil {
		return "", fmt.Errorf("pull image: %w", err)
	}

	// Create network if specified
	if runParams.NetworkMode != "" && runParams.NetworkMode != "host" && runParams.NetworkMode != "none" {
		_, err := m.runtime.NetworkCreate(contracts.NetworkCreateParams{
			Name:   runParams.NetworkMode,
			Driver: contracts.NetworkDriverBridge,
		})
		if err != nil {
			m.log.Warn("network may already exist", logger.String("network", runParams.NetworkMode), logger.Error(err))
		}
	}

	// Run container
	containerID, err := m.runtime.ContainerRun(*runParams)
	if err != nil {
		return "", fmt.Errorf("run container: %w", err)
	}

	m.log.Info("container started",
		logger.String("service", name),
		logger.String("container_id", containerID),
		logger.String("endpoint", m.name),
	)

	// Execute post-install hooks
	for _, hook := range svc.PostInstall {
		m.executeHook(hook)
	}

	return containerID, nil
}

func (m *serviceManager) Uninstall(name string) error {
	containers, err := m.runtime.ContainerList(true)
	if err != nil {
		return fmt.Errorf("list containers: %w", err)
	}

	for _, c := range containers {
		if c.Labels[contracts.ManagedServiceLabel] == name {
			if err := m.runtime.ContainerStop(c.ID); err != nil {
				m.log.Warn("stop container", logger.String("id", c.ID), logger.Error(err))
			}
			if err := m.runtime.ContainerRemove(c.ID, true); err != nil {
				return fmt.Errorf("remove container: %w", err)
			}
			m.log.Info("container removed", logger.String("service", name), logger.String("id", c.ID))
		}
	}
	return nil
}

func (m *serviceManager) Status(name string) (*contracts.ServiceStatusResult, error) {
	containers, err := m.runtime.ContainerList(true)
	if err != nil {
		return nil, fmt.Errorf("list containers: %w", err)
	}

	for _, c := range containers {
		if c.Labels[contracts.ManagedServiceLabel] == name {
			status := contracts.ServiceStatusInstalled
			if c.State == "running" {
				status = contracts.ServiceStatusRunning
			} else if c.State == "exited" || c.State == "stopped" {
				status = contracts.ServiceStatusStopped
			}
			return &contracts.ServiceStatusResult{Name: name, Status: status}, nil
		}
	}
	return &contracts.ServiceStatusResult{Name: name, Status: contracts.ServiceStatusNotInstalled}, nil
}

func (m *serviceManager) Restart(name string) error {
	containers, err := m.runtime.ContainerList(true)
	if err != nil {
		return fmt.Errorf("list containers: %w", err)
	}

	for _, c := range containers {
		if c.Labels[contracts.ManagedServiceLabel] == name {
			if err := m.runtime.ContainerStop(c.ID); err != nil {
				return fmt.Errorf("stop: %w", err)
			}
			m.log.Info("container restarted", logger.String("service", name), logger.String("id", c.ID))
			return nil
		}
	}
	return fmt.Errorf("service %q not installed", name)
}

func (m *serviceManager) Update(name string) error {
	allParams, err := m.paramStore.GetAll()
	if err != nil {
		return err
	}
	if err := m.Uninstall(name); err != nil {
		return err
	}
	if _, err = m.Install(name, allParams, ""); err != nil {
		return err
	}
	return nil
}

func (m *serviceManager) PreCheck(name string, params []*contracts.ParamValue) error {
	svc, err := m.serviceLoader.Load(name)
	if err != nil {
		return err
	}
	paramMap := make(map[string]*contracts.ParamValue, len(params))
	for _, p := range params {
		paramMap[p.Name] = p
	}
	for _, def := range svc.Params {
		if def.Required {
			if _, ok := paramMap[def.Name]; !ok {
				return fmt.Errorf("required param %q missing", def.Name)
			}
		}
	}
	return nil
}

func (m *serviceManager) Preview(name string, params []*contracts.ParamValue) (*contracts.ContainerRunParams, error) {
	svc, err := m.serviceLoader.Load(name)
	if err != nil {
		return nil, err
	}
	return m.buildRunParams(svc, params)
}

func (m *serviceManager) RenderConfig(name string, params []*contracts.ParamValue) (map[string]string, error) {
	svc, err := m.serviceLoader.Load(name)
	if err != nil {
		return nil, err
	}
	if svc.Container == nil {
		return nil, nil
	}
	data := m.newTemplateData(svc, params)
	result := make(map[string]string)
	if svc.Container.Env != nil {
		for k, v := range svc.Container.Env {
			rendered, err := m.templateEngine.RenderString(v, data)
			if err != nil {
				return nil, fmt.Errorf("render env %s: %w", k, err)
			}
			result[k] = rendered
		}
	}
	return result, nil
}

func (m *serviceManager) buildRunParams(svc *contracts.ServiceDefinition, params []*contracts.ParamValue) (*contracts.ContainerRunParams, error) {
	if svc.Container == nil {
		return nil, fmt.Errorf("service %q has no container config", svc.Name)
	}

	data := m.newTemplateData(svc, params)

	// Render env vars through template engine to resolve {{ .Custom.* }} and {{ index .Params "*" }}
	env := make(map[string]string)
	for k, v := range svc.Container.Env {
		rendered, err := m.templateEngine.RenderString(v, data)
		if err != nil {
			m.log.Warn("template render failed, using raw value",
				logger.String("key", k), logger.Error(err))
			env[k] = v
		} else {
			env[k] = rendered
		}
	}

	// Apply param-based env overrides from EnvMapping
	paramMap := make(map[string]*contracts.ParamValue, len(params))
	for _, p := range params {
		paramMap[p.Name] = p
	}
	for _, def := range svc.Params {
		if pv, ok := paramMap[def.Name]; ok {
			if def.EnvMapping != nil {
				for envKey := range def.EnvMapping {
					if val, ok := pv.Value.(string); ok {
						env[envKey] = val
					}
				}
			}
		}
	}

	labels := make(map[string]string)
	for k, v := range svc.Container.Labels {
		labels[k] = v
	}
	repo := svc.Source
	if repo == "" {
		repo = "builtin"
	}
	for k, v := range contracts.ManagedLabels(svc.Name, repo, svc.APIVersion, m.name, "docker") {
		labels[k] = v
	}

	runParams := &contracts.ContainerRunParams{
		Image:         svc.Container.Image,
		Name:          svc.Container.Name,
		Command:       svc.Container.Command,
		Entrypoint:    svc.Container.Entrypoint,
		Env:           env,
		Ports:         svc.Container.Ports,
		Volumes:       svc.Container.Volumes,
		Devices:       svc.Container.Devices,
		NetworkMode:   svc.Container.NetworkMode,
		RestartPolicy: svc.Container.RestartPolicy,
		Privileged:    svc.Container.Privileged,
		User:          svc.Container.User,
		Labels:        labels,
		CapAdd:        svc.Container.CapAdd,
		CapDrop:       svc.Container.CapDrop,
		Sysctls:       svc.Container.Sysctls,
		ExtraHosts:    svc.Container.ExtraHosts,
		DNS:           svc.Container.DNS,
		NetworkAliases: nil,
		Healthcheck:   nil,
		Resources:     nil,
	}
	return runParams, nil
}

// newTemplateData builds a TemplateData with Custom values from the endpoint config.
func (m *serviceManager) newTemplateData(svc *contracts.ServiceDefinition, params []*contracts.ParamValue) *contracts.TemplateData {
	data := &contracts.TemplateData{
		Service:  svc,
		Params:   params,
		Endpoint: m.endpoint,
	}
	if m.endpoint != nil && len(m.endpoint.Custom) > 0 {
		data.Custom = m.endpoint.Custom
	}
	data.BuildParamMap()
	return data
}

func (m *serviceManager) executeHook(hook *contracts.PostInstallHook) {
	m.log.Info("post-install hook", logger.String("type", hook.Type))
	if hook.Message != "" {
		m.log.Warn(hook.Message)
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && searchString(s, substr)
}

func searchString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
