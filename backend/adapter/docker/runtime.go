package docker

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

type Runtime struct {
	binary string
	cfg    contracts.ConnectionConfig
}

func NewRuntime(cfg contracts.ConnectionConfig) (*Runtime, error) {
	binary, err := exec.LookPath("docker")
	if err != nil {
		return nil, fmt.Errorf("docker not found: %w", err)
	}
	return &Runtime{binary: binary, cfg: cfg}, nil
}

func (r *Runtime) docker(args ...string) (string, error) {
	cmd := exec.Command(r.binary, args...)
	if r.cfg.Endpoint != "" && r.cfg.Type == contracts.ConnectionTypeUnix {
		cmd.Env = append(cmd.Env, "DOCKER_HOST=unix://"+r.cfg.Endpoint)
	}
	if r.cfg.Endpoint != "" && r.cfg.Type == contracts.ConnectionTypeTCP {
		cmd.Env = append(cmd.Env, "DOCKER_HOST=tcp://"+r.cfg.Endpoint)
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("docker %s: %s: %w", strings.Join(args, " "), strings.TrimSpace(string(out)), err)
	}
	return strings.TrimSpace(string(out)), nil
}

func (r *Runtime) ContainerRun(params contracts.ContainerRunParams) (string, error) {
	args := []string{"run", "-d"}
	if params.Name != "" {
		args = append(args, "--name", params.Name)
	}
	if params.RestartPolicy != "" {
		args = append(args, "--restart", string(params.RestartPolicy))
	}
	if params.NetworkMode != "" {
		args = append(args, "--network", params.NetworkMode)
	}
	if params.User != "" {
		args = append(args, "--user", params.User)
	}
	if params.Privileged {
		args = append(args, "--privileged")
	}
	if params.Entrypoint != nil {
		args = append(args, "--entrypoint", strings.Join(params.Entrypoint, " "))
	}
	for _, p := range params.Ports {
		proto := p.Protocol
		if proto == "" {
			proto = "tcp"
		}
		args = append(args, "-p", fmt.Sprintf("%d:%d/%s", p.HostPort, p.ContainerPort, proto))
	}
	for _, v := range params.Volumes {
		opt := v.Source + ":" + v.Target
		if v.ReadOnly {
			opt += ":ro"
		}
		args = append(args, "-v", opt)
	}
	for _, d := range params.Devices {
		args = append(args, "--device", d.HostPath+":"+d.ContainerPath)
	}
	for k, v := range params.Env {
		args = append(args, "-e", k+"="+v)
	}
	for k, v := range params.Labels {
		args = append(args, "-l", k+"="+v)
	}
	for _, c := range params.CapAdd {
		args = append(args, "--cap-add", c)
	}
	for _, c := range params.CapDrop {
		args = append(args, "--cap-drop", c)
	}
	for _, h := range params.ExtraHosts {
		args = append(args, "--add-host", h)
	}
	for _, d := range params.DNS {
		args = append(args, "--dns", d)
	}
	for _, a := range params.NetworkAliases {
		args = append(args, "--network-alias", a)
	}
	if params.Resources != nil {
		if params.Resources.CPUs != "" {
			args = append(args, "--cpus", params.Resources.CPUs)
		}
		if params.Resources.Memory != "" {
			args = append(args, "--memory", params.Resources.Memory)
		}
	}
	for k, v := range params.Sysctls {
		args = append(args, "--sysctl", k+"="+v)
	}
	args = append(args, params.Image)
	args = append(args, params.Command...)
	return r.docker(args...)
}

func (r *Runtime) ContainerStop(containerID string) error {
	_, err := r.docker("stop", containerID)
	return err
}

func (r *Runtime) ContainerRemove(containerID string, force bool) error {
	args := []string{"rm"}
	if force {
		args = append(args, "-f")
	}
	args = append(args, containerID)
	_, err := r.docker(args...)
	return err
}

func (r *Runtime) ContainerInspect(containerID string) (*contracts.ContainerInfo, error) {
	out, err := r.docker("inspect", containerID)
	if err != nil {
		return nil, err
	}
	var containers []contracts.ContainerInfo
	if err := json.Unmarshal([]byte(out), &containers); err != nil {
		return nil, err
	}
	if len(containers) == 0 {
		return nil, fmt.Errorf("container %q not found", containerID)
	}
	return &containers[0], nil
}

func (r *Runtime) ContainerExec(containerID string, command []string) (string, error) {
	args := append([]string{"exec", containerID}, command...)
	return r.docker(args...)
}

func (r *Runtime) ContainerLogs(containerID string, tail int) (string, error) {
	args := []string{"logs", "--tail", fmt.Sprintf("%d", tail)}
	if tail <= 0 {
		args = []string{"logs"}
	}
	args = append(args, containerID)
	return r.docker(args...)
}

func (r *Runtime) ContainerList(all bool) ([]contracts.ContainerInfo, error) {
	args := []string{"ps", "--format", "{{json .}}"}
	if all {
		args = append(args, "-a")
	}
	out, err := r.docker(args...)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(out, "\n")
	var result []contracts.ContainerInfo
	for _, line := range lines {
		if line == "" {
			continue
		}
		var c contracts.ContainerInfo
		if err := json.Unmarshal([]byte(line), &c); err != nil {
			continue
		}
		result = append(result, c)
	}
	return result, nil
}

func (r *Runtime) PullImage(image string) error {
	_, err := r.docker("pull", image)
	return err
}

func (r *Runtime) ImageList() ([]contracts.ImageInfo, error) {
	out, err := r.docker("images", "--format", "{{json .}}")
	if err != nil {
		return nil, err
	}
	lines := strings.Split(out, "\n")
	var result []contracts.ImageInfo
	for _, line := range lines {
		if line == "" {
			continue
		}
		var img contracts.ImageInfo
		if err := json.Unmarshal([]byte(line), &img); err != nil {
			continue
		}
		result = append(result, img)
	}
	return result, nil
}

func (r *Runtime) NetworkCreate(params contracts.NetworkCreateParams) (string, error) {
	args := []string{"network", "create"}
	if params.Driver != "" {
		args = append(args, "--driver", string(params.Driver))
	}
	if params.Internal {
		args = append(args, "--internal")
	}
	if params.Attachable {
		args = append(args, "--attachable")
	}
	if params.Subnet != "" {
		args = append(args, "--subnet", params.Subnet)
	}
	if params.Gateway != "" {
		args = append(args, "--gateway", params.Gateway)
	}
	if params.IPRange != "" {
		args = append(args, "--ip-range", params.IPRange)
	}
	for k, v := range params.Labels {
		args = append(args, "-l", k+"="+v)
	}
	args = append(args, params.Name)
	return r.docker(args...)
}

func (r *Runtime) NetworkRemove(networkID string) error {
	_, err := r.docker("network", "rm", networkID)
	return err
}

func (r *Runtime) NetworkInspect(networkID string) (*contracts.NetworkInfo, error) {
	out, err := r.docker("network", "inspect", networkID)
	if err != nil {
		return nil, err
	}
	var networks []contracts.NetworkInfo
	if err := json.Unmarshal([]byte(out), &networks); err != nil {
		return nil, err
	}
	if len(networks) == 0 {
		return nil, fmt.Errorf("network %q not found", networkID)
	}
	return &networks[0], nil
}

func (r *Runtime) NetworkList() ([]contracts.NetworkInfo, error) {
	out, err := r.docker("network", "ls", "--format", "{{json .}}")
	if err != nil {
		return nil, err
	}
	lines := strings.Split(out, "\n")
	var result []contracts.NetworkInfo
	for _, line := range lines {
		if line == "" {
			continue
		}
		var n contracts.NetworkInfo
		if err := json.Unmarshal([]byte(line), &n); err != nil {
			continue
		}
		result = append(result, n)
	}
	return result, nil
}

func (r *Runtime) NetworkConnect(networkID string, containerID string) error {
	_, err := r.docker("network", "connect", networkID, containerID)
	return err
}

func (r *Runtime) VolumeCreate(params contracts.VolumeCreateParams) (string, error) {
	args := []string{"volume", "create"}
	if params.Driver != "" {
		args = append(args, "--driver", params.Driver)
	}
	for k, v := range params.Labels {
		args = append(args, "-l", k+"="+v)
	}
	args = append(args, params.Name)
	return r.docker(args...)
}

func (r *Runtime) VolumeRemove(volumeID string, force bool) error {
	args := []string{"volume", "rm"}
	if force {
		args = append(args, "-f")
	}
	args = append(args, volumeID)
	_, err := r.docker(args...)
	return err
}

func (r *Runtime) VolumeInspect(volumeID string) (*contracts.VolumeInfo, error) {
	out, err := r.docker("volume", "inspect", volumeID)
	if err != nil {
		return nil, err
	}
	var volumes []contracts.VolumeInfo
	if err := json.Unmarshal([]byte(out), &volumes); err != nil {
		return nil, err
	}
	if len(volumes) == 0 {
		return nil, fmt.Errorf("volume %q not found", volumeID)
	}
	return &volumes[0], nil
}

func (r *Runtime) VolumeList() ([]contracts.VolumeInfo, error) {
	out, err := r.docker("volume", "ls", "--format", "{{json .}}")
	if err != nil {
		return nil, err
	}
	lines := strings.Split(out, "\n")
	var result []contracts.VolumeInfo
	for _, line := range lines {
		if line == "" {
			continue
		}
		var v contracts.VolumeInfo
		if err := json.Unmarshal([]byte(line), &v); err != nil {
			continue
		}
		result = append(result, v)
	}
	return result, nil
}

func (r *Runtime) Ping() error {
	_, err := r.docker("info")
	return err
}

func (r *Runtime) Info() (*contracts.RuntimeInfo, error) {
	out, err := r.docker("info", "--format", "{{json .}}")
	if err != nil {
		return nil, err
	}
	var info struct {
		ServerVersion string `json:"ServerVersion"`
		OperatingSystem string `json:"OperatingSystem"`
		Architecture   string `json:"Architecture"`
		Name           string `json:"Name"`
	}
	if err := json.Unmarshal([]byte(out), &info); err != nil {
		return nil, err
	}
	return &contracts.RuntimeInfo{
		Engine:  contracts.EngineTypeDocker,
		Version: info.ServerVersion,
		OS:      info.OperatingSystem,
		Arch:    info.Architecture,
		Name:    info.Name,
	}, nil
}
