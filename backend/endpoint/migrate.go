package endpoint

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time check: *migrateService implements contracts.MigrateService.
var _ contracts.MigrateService = (*migrateService)(nil)

type migrateService struct {
	runtime       contracts.ContainerRuntime
	serviceLoader contracts.ServiceLoader
	serviceMgr    contracts.ServiceManager
	log           logger.Logger
	name          string
}

func NewMigrateService(
	runtime contracts.ContainerRuntime,
	serviceLoader contracts.ServiceLoader,
	serviceMgr contracts.ServiceManager,
	log logger.Logger,
	name string,
) contracts.MigrateService {
	return &migrateService{
		runtime:       runtime,
		serviceLoader: serviceLoader,
		serviceMgr:    serviceMgr,
		log:           log,
		name:          name,
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
