package endpoint

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
	"github.com/dezhishen/self-hosted-server-traefik/backend/service"
	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"gopkg.in/yaml.v3"
)

// Compile-time check: *migrateService implements contracts.MigrateService.
var _ contracts.MigrateService = (*migrateService)(nil)

type migrateService struct {
	runtime       contracts.ContainerRuntime
	serviceLoader contracts.ServiceLoader
	serviceMgr    contracts.ServiceManager
	log           logger.Logger
	name          string
	generatedDir  string
}

func NewMigrateService(
	runtime contracts.ContainerRuntime,
	serviceLoader contracts.ServiceLoader,
	serviceMgr contracts.ServiceManager,
	log logger.Logger,
	name string,
	generatedDir string,
) contracts.MigrateService {
	return &migrateService{
		runtime:       runtime,
		serviceLoader: serviceLoader,
		serviceMgr:    serviceMgr,
		log:           log,
		name:          name,
		generatedDir:  generatedDir,
	}
}

func (m *migrateService) matchContainer(container *contracts.ContainerInfo, services []*contracts.ServiceDefinition) string {
	for _, svc := range services {
		for _, pattern := range svc.Images {
			if matched, _ := filepath.Match(pattern, container.Image); matched {
				return svc.Name
			}
		}
	}
	return ""
}

func (m *migrateService) extractParams(container *contracts.ContainerInfo, service *contracts.ServiceDefinition) []*contracts.ParamValue {
	var result []*contracts.ParamValue
	for _, def := range service.Params {
		val := m.extractParam(def, container)
		result = append(result, val)
	}
	return result
}

func (m *migrateService) extractParam(def *contracts.ParamDef, container *contracts.ContainerInfo) *contracts.ParamValue {
	if def.EnvMapping != nil {
		for envKey := range def.EnvMapping {
			if v, ok := container.Env[envKey]; ok {
				return &contracts.ParamValue{Name: def.Name, Value: v}
			}
		}
	}
	labelKey := "selfhosted.param." + def.Name
	if v, ok := container.Labels[labelKey]; ok {
		return &contracts.ParamValue{Name: def.Name, Value: v}
	}
	if def.Type == contracts.ParamTypeNumber || def.Type == contracts.ParamTypeString {
		for _, port := range container.Ports {
			if strconv.Itoa(port.ContainerPort) == def.Name || strings.Contains(def.Name, fmt.Sprintf("_%d", port.ContainerPort)) {
				return &contracts.ParamValue{Name: def.Name, Value: port.HostPort}
			}
		}
	}
	if def.Default != nil {
		return &contracts.ParamValue{Name: def.Name, Value: def.Default}
	}
	return &contracts.ParamValue{Name: def.Name, Value: ""}
}

func (m *migrateService) Analyze(epName string) ([]*contracts.MigrationCandidate, error) {
	containers, err := m.runtime.ContainerList(true)
	if err != nil {
		return nil, fmt.Errorf("list containers: %w", err)
	}

	services, err := m.serviceLoader.LoadAll()
	if err != nil {
		return nil, fmt.Errorf("load services: %w", err)
	}

	serviceNames := make([]string, len(services))
	for i, s := range services {
		serviceNames[i] = s.Name
	}

	var candidates []*contracts.MigrationCandidate
	for i := range containers {
		c := &containers[i]
		if c.Labels[contracts.ManagedLabelKey] == contracts.ManagedLabelValue {
			continue
		}
		candidate := &contracts.MigrationCandidate{
			Container: c,
			Services:  serviceNames,
		}
		matched := m.matchContainer(c, services)
		if matched != "" {
			candidate.MatchedService = matched
			for _, svc := range services {
				if svc.Name == matched {
					candidate.ExtractedParams = m.extractParams(c, svc)
					break
				}
			}
		}
		candidates = append(candidates, candidate)
	}
	return candidates, nil
}

func (m *migrateService) Execute(req *contracts.MigrationRequest) (string, error) {
	container, err := m.runtime.ContainerInspect(req.ContainerID)
	if err != nil {
		return "", fmt.Errorf("inspect container: %w", err)
	}

	if container.Labels[contracts.ManagedLabelKey] == contracts.ManagedLabelValue {
		return "", fmt.Errorf("container %s is already managed", req.ContainerID)
	}

	newID, err := m.serviceMgr.Install(req.ServiceName, req.Params, m.name)
	if err != nil {
		return "", fmt.Errorf("install service: %w", err)
	}

	if req.RemoveOld {
		if err := m.runtime.ContainerStop(req.ContainerID); err != nil {
			m.log.Warn("stop old container", logger.String("id", req.ContainerID), logger.Error(err))
		}
		if err := m.runtime.ContainerRemove(req.ContainerID, true); err != nil {
			m.log.Warn("remove old container", logger.String("id", req.ContainerID), logger.Error(err))
		}
	}

	m.log.Info("migration complete",
		logger.String("service", req.ServiceName),
		logger.String("old_id", req.ContainerID),
		logger.String("new_id", newID),
	)
	return newID, nil
}

func (m *migrateService) Generate(req *contracts.GenerateTemplateRequest) (*contracts.GenerateTemplateResult, error) {
	container, err := m.runtime.ContainerInspect(req.ContainerID)
	if err != nil {
		return nil, fmt.Errorf("inspect container: %w", err)
	}

	svc := m.buildServiceDef(req.ServiceName, container)
	data, err := yaml.Marshal(svc)
	if err != nil {
		return nil, fmt.Errorf("marshal service definition: %w", err)
	}

	if err := os.MkdirAll(m.generatedDir, 0755); err != nil {
		return nil, fmt.Errorf("create generated dir: %w", err)
	}

	filePath := filepath.Join(m.generatedDir, req.ServiceName+".yaml")
	if err := os.WriteFile(filePath, data, 0644); err != nil {
		return nil, fmt.Errorf("write template file: %w", err)
	}

	// Register the generated directory with the loader via type assertion.
	if loader, ok := m.serviceLoader.(*service.Loader); ok {
		loader.AddPath(m.generatedDir)
	}

	m.log.Info("template generated",
		logger.String("service", req.ServiceName),
		logger.String("file", filePath),
	)
	return &contracts.GenerateTemplateResult{
		ServiceName: req.ServiceName,
		FilePath:    filePath,
	}, nil
}

// Adopt takes an existing running container and makes it a managed service by
// adding management labels. The container is NOT stopped or recreated — labels
// are applied in-place via the Docker API's container update endpoint.
func (m *migrateService) Adopt(req *contracts.AdoptRequest) (*contracts.AdoptResult, error) {
	container, err := m.runtime.ContainerInspect(req.ContainerID)
	if err != nil {
		return nil, fmt.Errorf("inspect container: %w", err)
	}

	// Check if already managed
	if container.Labels[contracts.ManagedLabelKey] == contracts.ManagedLabelValue {
		return nil, fmt.Errorf("container %s is already managed", req.ContainerID)
	}

	serviceName := req.ServiceName
	if serviceName == "" {
		// Default to container name (strip leading /)
		serviceName = strings.TrimPrefix(container.Name, "/")
	}

	version := req.Version
	if version == "" {
		version = "adopted"
	}

	// Build the managed labels
	managedLabels := contracts.ManagedLabels(serviceName, version, m.name, "docker")

	// Apply labels to the running container
	if err := m.runtime.ContainerUpdateLabels(req.ContainerID, managedLabels); err != nil {
		return nil, fmt.Errorf("update container labels: %w", err)
	}

	m.log.Info("container adopted as managed service",
		logger.String("container_id", req.ContainerID),
		logger.String("service", serviceName),
		logger.String("endpoint", m.name),
	)

	return &contracts.AdoptResult{
		ContainerID: req.ContainerID,
		ServiceName: serviceName,
		Endpoint:    m.name,
		Labels:      managedLabels,
	}, nil
}

// buildServiceDef constructs a ServiceDefinition from a running container's info.
func (m *migrateService) buildServiceDef(name string, c *contracts.ContainerInfo) *contracts.ServiceDefinition {
	svc := &contracts.ServiceDefinition{
		Name:  name,
		Image: c.Image,
		Container: &contracts.ContainerConfig{
			Image: c.Image,
			Env:   c.Env,
			Ports: c.Ports,
		},
	}

	// Mounts → Volumes
	if len(c.Mounts) > 0 {
		svc.Container.Volumes = make([]contracts.VolumeMount, len(c.Mounts))
		copy(svc.Container.Volumes, c.Mounts)
	}

	// Command
	if len(c.Command) > 0 {
		svc.Container.Command = c.Command
	}

	// Entrypoint
	if len(c.Entrypoint) > 0 {
		svc.Container.Entrypoint = c.Entrypoint
	}

	// User
	if c.User != "" {
		svc.Container.User = c.User
	}

	// RestartPolicy
	if c.RestartPolicy != "" {
		svc.Container.RestartPolicy = contracts.RestartPolicy(c.RestartPolicy)
	}

	// NetworkMode
	if c.NetworkMode != "" {
		svc.Container.NetworkMode = c.NetworkMode
	}

	// Privileged
	if c.Privileged {
		svc.Container.Privileged = true
	}

	// CapAdd / CapDrop
	if len(c.CapAdd) > 0 {
		svc.Container.CapAdd = c.CapAdd
	}
	if len(c.CapDrop) > 0 {
		svc.Container.CapDrop = c.CapDrop
	}

	// DNS
	if len(c.DNS) > 0 {
		svc.Container.DNS = c.DNS
	}

	// ExtraHosts
	if len(c.ExtraHosts) > 0 {
		svc.Container.ExtraHosts = c.ExtraHosts
	}

	// Labels — filter out system labels (managed / selfhosted prefix)
	if len(c.Labels) > 0 {
		filtered := make(map[string]string)
		for k, v := range c.Labels {
			if strings.HasPrefix(k, "selfhosted.") {
				continue
			}
			if strings.HasPrefix(k, "traefik.") {
				continue
			}
			filtered[k] = v
		}
		if len(filtered) > 0 {
			svc.Container.Labels = filtered
		}
	}

	return svc
}
