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
	paramStore    contracts.ParamStore
}

func NewMigrateService(
	runtime contracts.ContainerRuntime,
	serviceLoader contracts.ServiceLoader,
	serviceMgr contracts.ServiceManager,
	paramStore contracts.ParamStore,
	log logger.Logger,
	name string,
	generatedDir string,
) contracts.MigrateService {
	return &migrateService{
		runtime:       runtime,
		serviceLoader: serviceLoader,
		serviceMgr:    serviceMgr,
		paramStore:    paramStore,
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



func (m *migrateService) Generate(req *contracts.GenerateAppRequest) (*contracts.GenerateAppResult, error) {
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

	m.log.Info("app definition generated",
		logger.String("service", req.ServiceName),
		logger.String("file", filePath),
	)
	return &contracts.GenerateAppResult{
		ServiceName: req.ServiceName,
		FilePath:    filePath,
	}, nil
}

// Adopt rebuilds an existing container as a managed service.
// The original container is stopped and removed, then a new container is created
// with the same configuration plus managed labels. If req.ServiceName matches a
// known service template, the template's install pipeline is used; otherwise the
// container is cloned directly from its current configuration.
func (m *migrateService) Adopt(req *contracts.AdoptRequest) (*contracts.AdoptResult, error) {
	container, err := m.runtime.ContainerInspect(req.ContainerID)
	if err != nil {
		return nil, fmt.Errorf("inspect container: %w", err)
	}

	if container.Labels[contracts.ManagedLabelKey] == contracts.ManagedLabelValue {
		return nil, fmt.Errorf("container %s is already managed", req.ContainerID)
	}

	serviceName := req.ServiceName
	if serviceName == "" {
		serviceName = strings.TrimPrefix(container.Name, "/")
	}

	version := req.Version
	if version == "" {
		version = "adopted"
	}

	repoName := req.RepoName
	if repoName == "" {
		repoName = "adopted"
	}

	managedLabels := contracts.ManagedLabels(serviceName, repoName, version, m.name, "docker")
	var newID string

	if req.ServiceName != "" && len(req.Params) > 0 {
		// Rebuild via service template: install with params, label the new container.
		newID, err = m.serviceMgr.Install(req.ServiceName, req.Params, m.name)
		if err != nil {
			return nil, fmt.Errorf("install service: %w", err)
		}
	} else {
		// No template match: clone the container from its current config.
		runParams := containerToRunParams(container, managedLabels)
		runParams.Name = "" // Let Docker generate a unique name to avoid conflict with the original
		newID, err = m.runtime.ContainerRun(runParams)
		if err != nil {
			return nil, fmt.Errorf("clone container: %w", err)
		}
	}

	// Stop and remove the original container.
	if err := m.runtime.ContainerStop(req.ContainerID); err != nil {
		m.log.Warn("stop old container", logger.String("id", req.ContainerID), logger.Error(err))
	}
	if err := m.runtime.ContainerRemove(req.ContainerID, true); err != nil {
		m.log.Warn("remove old container", logger.String("id", req.ContainerID), logger.Error(err))
	}

	newContainer, err := m.runtime.ContainerInspect(newID)
	if err != nil {
		return nil, fmt.Errorf("inspect new container: %w", err)
	}
	resultLabels := newContainer.Labels
	if resultLabels == nil {
		resultLabels = managedLabels
	}

	m.log.Info("container rebuilt and adopted",
		logger.String("service", serviceName),
		logger.String("old_id", req.ContainerID),
		logger.String("new_id", newID),
	)

	return &contracts.AdoptResult{
		ContainerID: newID,
		ServiceName: serviceName,
		RepoName:    repoName,
		Endpoint:    m.name,
		Labels:      resultLabels,
	}, nil
}

// buildAdoptParams extracts a container's current configuration into ParamValue
// entries and saves them to the param store so the adopted container is
// discoverable as a managed service.
func (m *migrateService) buildAdoptParams(serviceName string, c *contracts.ContainerInfo) []*contracts.ParamValue {
	var params []*contracts.ParamValue

	// Image
	if c.Image != "" {
		params = append(params, &contracts.ParamValue{Name: serviceName + "_image", Value: c.Image})
	}

	// Environment — store as JSON map
	if len(c.Env) > 0 {
		envMap := make(map[string]string)
		for k, v := range c.Env {
			envMap[k] = v
		}
		params = append(params, &contracts.ParamValue{Name: serviceName + "_env", Value: envMap})
	}

	// Ports
	for _, p := range c.Ports {
		portName := fmt.Sprintf("%s_port_%d", serviceName, p.ContainerPort)
		params = append(params, &contracts.ParamValue{Name: portName, Value: p.HostPort})
	}

	// Volumes / Mounts
	for i, mnt := range c.Mounts {
		mountName := fmt.Sprintf("%s_volume_%d", serviceName, i)
		params = append(params, &contracts.ParamValue{Name: mountName, Value: mnt.Source + ":" + mnt.Target})
	}

	// Restart policy
	if c.RestartPolicy != "" {
		params = append(params, &contracts.ParamValue{Name: serviceName + "_restart", Value: c.RestartPolicy})
	}

	// Network mode
	if c.NetworkMode != "" {
		params = append(params, &contracts.ParamValue{Name: serviceName + "_network", Value: c.NetworkMode})
	}

	// Privileged
	if c.Privileged {
		params = append(params, &contracts.ParamValue{Name: serviceName + "_privileged", Value: "true"})
	}

	// CapAdd / CapDrop
	if len(c.CapAdd) > 0 {
		params = append(params, &contracts.ParamValue{Name: serviceName + "_cap_add", Value: c.CapAdd})
	}
	if len(c.CapDrop) > 0 {
		params = append(params, &contracts.ParamValue{Name: serviceName + "_cap_drop", Value: c.CapDrop})
	}

	// DNS
	if len(c.DNS) > 0 {
		params = append(params, &contracts.ParamValue{Name: serviceName + "_dns", Value: c.DNS})
	}

	// ExtraHosts
	if len(c.ExtraHosts) > 0 {
		params = append(params, &contracts.ParamValue{Name: serviceName + "_extra_hosts", Value: c.ExtraHosts})
	}

	return params
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

// containerToRunParams converts a ContainerInfo into ContainerRunParams,
// merging in the given labels (which should include managed service labels).
func containerToRunParams(c *contracts.ContainerInfo, labels map[string]string) contracts.ContainerRunParams {
	mergedLabels := make(map[string]string)
	for k, v := range c.Labels {
		mergedLabels[k] = v
	}
	for k, v := range labels {
		mergedLabels[k] = v
	}

	env := make(map[string]string)
	for k, v := range c.Env {
		env[k] = v
	}

	return contracts.ContainerRunParams{
		Image:         c.Image,
		Name:          c.Name,
		Hostname:      c.Hostname,
		Command:       c.Command,
		Entrypoint:    c.Entrypoint,
		WorkingDir:    c.WorkingDir,
		Env:           env,
		Ports:         c.Ports,
		Volumes:       c.Mounts,
		Devices:       c.Devices,
		NetworkMode:   c.NetworkMode,
		RestartPolicy: contracts.RestartPolicy(c.RestartPolicy),
		Privileged:    c.Privileged,
		User:          c.User,
		Labels:        mergedLabels,
		CapAdd:        c.CapAdd,
		CapDrop:       c.CapDrop,
		Sysctls:       c.Sysctls,
		Tty:           c.Tty,
		Healthcheck:   c.Healthcheck,
		Resources:     c.Resources,
		ExtraHosts:    c.ExtraHosts,
		DNS:           c.DNS,
		DNSSearch:     c.DNSSearch,
	}
}

// PreviewAdopt returns a preview of what would happen during adoption without
// actually creating the container. It inspects the container, builds the run
// parameters, and generates a human-readable docker run command.
func (m *migrateService) PreviewAdopt(req *contracts.AdoptPreviewRequest) (*contracts.AdoptPreviewResult, error) {
	container, err := m.runtime.ContainerInspect(req.ContainerID)
	if err != nil {
		return nil, fmt.Errorf("inspect container: %w", err)
	}

	serviceName := req.ServiceName
	if serviceName == "" {
		serviceName = strings.TrimPrefix(container.Name, "/")
	}

	// If params are provided via a known template, use serviceMgr.Preview instead.
	if req.ServiceName != "" && len(req.Params) > 0 {
		runParams, err := m.serviceMgr.Preview(req.ServiceName, req.Params)
		if err != nil {
			return nil, fmt.Errorf("preview service install: %w", err)
		}
		if runParams == nil {
			return nil, fmt.Errorf("preview returned nil params for service %q", req.ServiceName)
		}
		dockerCmd := generateDockerRunCmd(runParams)
		return &contracts.AdoptPreviewResult{
			RunParams:      runParams,
			DockerRunCmd:   dockerCmd,
			ServiceName:    serviceName,
			OriginalLabels: container.Labels,
		}, nil
	}

	// No template: clone from current container config.
	managedLabels := contracts.ManagedLabels(serviceName, "adopted", "adopted", m.name, "docker")
	runParams := containerToRunParams(container, managedLabels)
	dockerCmd := generateDockerRunCmd(&runParams)

	return &contracts.AdoptPreviewResult{
		RunParams:      &runParams,
		DockerRunCmd:   dockerCmd,
		ServiceName:    serviceName,
		OriginalLabels: container.Labels,
	}, nil
}

// generateDockerRunCmd produces a human-readable `docker run` command string
// from the given ContainerRunParams.
func generateDockerRunCmd(params *contracts.ContainerRunParams) string {
	var parts []string
	parts = append(parts, "docker", "run", "-d")

	if params.Name != "" {
		parts = append(parts, "--name", params.Name)
	}
	if params.Hostname != "" {
		parts = append(parts, "--hostname", params.Hostname)
	}
	if params.User != "" {
		parts = append(parts, "--user", params.User)
	}
	if params.WorkingDir != "" {
		parts = append(parts, "--workdir", params.WorkingDir)
	}
	if params.RestartPolicy != "" {
		parts = append(parts, "--restart", string(params.RestartPolicy))
	}
	if params.NetworkMode != "" {
		parts = append(parts, "--network", params.NetworkMode)
	}
	if params.Privileged {
		parts = append(parts, "--privileged")
	}
	if params.Tty {
		parts = append(parts, "-t")
	}
	for _, cap := range params.CapAdd {
		parts = append(parts, "--cap-add", cap)
	}
	for _, cap := range params.CapDrop {
		parts = append(parts, "--cap-drop", cap)
	}
	for k, v := range params.Labels {
		parts = append(parts, "--label", k+"="+v)
	}
	for k, v := range params.Env {
		parts = append(parts, "-e", k+"="+v)
	}
	for _, p := range params.Ports {
		portStr := fmt.Sprintf("%d:%d", p.HostPort, p.ContainerPort)
		proto := strings.ToLower(p.Protocol)
		if proto != "" && proto != "tcp" {
			portStr += "/" + proto
		}
		parts = append(parts, "-p", portStr)
	}
	for _, v := range params.Volumes {
		volStr := v.Source + ":" + v.Target
		if v.ReadOnly {
			volStr += ":ro"
		}
		parts = append(parts, "-v", volStr)
	}
	for _, d := range params.Devices {
		devStr := d.HostPath
		if d.ContainerPath != "" && d.ContainerPath != d.HostPath {
			devStr += ":" + d.ContainerPath
		}
		parts = append(parts, "--device", devStr)
	}
	for _, h := range params.ExtraHosts {
		parts = append(parts, "--add-host", h)
	}
	for _, dns := range params.DNS {
		parts = append(parts, "--dns", dns)
	}
	if len(params.Command) > 0 {
		parts = append(parts, "--")
		parts = append(parts, params.Command...)
	}

	return strings.Join(parts, " ")
}
