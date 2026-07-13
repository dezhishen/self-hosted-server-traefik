package docker

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	"strconv"
	"strings"
	"time"

	"github.com/moby/moby/client"
	"github.com/moby/moby/api/types/container"
	"github.com/moby/moby/api/types/image"
	"github.com/moby/moby/api/types/network"
	"github.com/moby/moby/api/types/system"
	"github.com/moby/moby/api/types/volume"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time check: *Runtime implements contracts.ContainerRuntime.
var _ contracts.ContainerRuntime = (*Runtime)(nil)

// Runtime implements contracts.ContainerRuntime using the Docker Go SDK.
// It connects directly to the Docker daemon API without requiring the docker CLI.
type Runtime struct {
	client     *client.Client
	httpClient *http.Client // raw HTTP client for API calls not exposed by moby SDK
	daemonHost string       // host:port portion from DaemonHost() for URL construction
	cancel     context.CancelFunc
	sshDial    *sshDialer // non-nil only for SSH connections
}

// unixDialer returns a dial function for the given Unix socket path.
func unixDialer(socketPath string) func(ctx context.Context, network, addr string) (net.Conn, error) {
	return func(ctx context.Context, network, addr string) (net.Conn, error) {
		var d net.Dialer
		return d.DialContext(ctx, "unix", socketPath)
	}
}

// NewRuntime creates a new Docker SDK runtime based on the connection config.
// Supported connection types: unix, tcp, http, https, ssh.
func NewRuntime(cfg contracts.ConnectionConfig) (*Runtime, error) {
	ctx, cancel := context.WithCancel(context.Background())

	rt := &Runtime{
		cancel: cancel,
	}

	opts := []client.Opt{
		client.WithAPIVersionNegotiation(),
	}

	switch cfg.Type {
	case contracts.ConnectionTypeUnix:
		endpoint := cfg.Endpoint
		if endpoint == "" {
			endpoint = "/var/run/docker.sock"
		}
		rt.httpClient = &http.Client{
			Transport: &http.Transport{
				DialContext: unixDialer(endpoint),
			},
		}
		opts = append(opts, client.WithHTTPClient(rt.httpClient))
		opts = append(opts, client.WithHost("http://docker"))

	case contracts.ConnectionTypeTCP, contracts.ConnectionTypeHTTP:
		endpoint := cfg.Endpoint
		if endpoint == "" {
			endpoint = "/var/run/docker.sock"
		}
		rt.httpClient = &http.Client{}
		rt.daemonHost = endpoint
		opts = append(opts, client.WithHTTPClient(rt.httpClient))
		opts = append(opts, client.WithHost("tcp://"+endpoint))

	case contracts.ConnectionTypeHTTPS:
		endpoint := cfg.Endpoint
		if endpoint == "" {
			return nil, fmt.Errorf("endpoint is required for https connection type")
		}
		host := "tcp://" + endpoint
		if cfg.TLS != nil && cfg.TLS.Enabled {
			tlsConfig, err := buildTLSConfig(cfg.TLS)
			if err != nil {
				cancel()
				return nil, fmt.Errorf("TLS config: %w", err)
			}
			transport := &http.Transport{
				TLSClientConfig: tlsConfig,
			}
			rt.httpClient = &http.Client{Transport: transport}
			opts = append(opts, client.WithHTTPClient(rt.httpClient))
		}
		rt.daemonHost = endpoint
		opts = append(opts, client.WithHost(host))

	case contracts.ConnectionTypeSSH:
		dialer, err := newSSHDialer(&cfg)
		if err != nil {
			cancel()
			return nil, fmt.Errorf("SSH dialer: %w", err)
		}
		rt.sshDial = dialer
		rt.httpClient = &http.Client{
			Transport: &http.Transport{
				DialContext: dialer.DialContext,
			},
		}
		opts = append(opts,
			client.WithHTTPClient(rt.httpClient),
			client.WithHost("http://docker"),
			client.WithDialContext(dialer.DialContext),
		)

	default:
		cancel()
		return nil, fmt.Errorf("unsupported connection type: %s", cfg.Type)
	}

	cli, err := client.NewClientWithOpts(opts...)
	if err != nil {
		cancel()
		return nil, fmt.Errorf("create Docker client: %w", err)
	}
	rt.client = cli

	// Derive daemonHost from the moby client for non-TCP schemes (unix/ssh)
	if rt.daemonHost == "" {
		rt.daemonHost = cli.DaemonHost()
	}

	// Verify connection
	if _, err := cli.Ping(ctx, client.PingOptions{}); err != nil {
		cli.Close()
		cancel()
		return nil, fmt.Errorf("Docker ping: %w", err)
	}

	return rt, nil
}

// Close cleans up the Docker client, cancels the context, and closes the SSH tunnel if any.
func (r *Runtime) Close() {
	r.cancel()
	if r.client != nil {
		r.client.Close()
	}
	if r.sshDial != nil {
		r.sshDial.Close()
	}
}

// ---------------------------------------------------------------------------
// Container operations
// ---------------------------------------------------------------------------

func (r *Runtime) ContainerRun(params contracts.ContainerRunParams) (string, error) {
	cfg := &container.Config{
		Image:        params.Image,
		Cmd:          params.Command,
		Entrypoint:   params.Entrypoint,
		Env:          mapToEnvSlice(params.Env),
		Labels:       params.Labels,
		ExposedPorts: nil, // ports are in HostConfig
	}
	if params.User != "" {
		cfg.User = params.User
	}

	hostCfg := &container.HostConfig{
		RestartPolicy: container.RestartPolicy{
			Name: mapRestartPolicy(params.RestartPolicy),
		},
		NetworkMode:  container.NetworkMode(params.NetworkMode),
		Privileged:   params.Privileged,
		PortBindings: mapPortBindings(params.Ports),
		Binds:        mapVolumeBinds(params.Volumes),
		CapAdd:       params.CapAdd,
		CapDrop:      params.CapDrop,
		ExtraHosts:   params.ExtraHosts,
		Sysctls:      params.Sysctls,
	}

	// Devices: set separately because it's promoted from the embedded Resources struct
	hostCfg.Devices = mapDevices(params.Devices)

	// DNS: convert []string to []netip.Addr
	if len(params.DNS) > 0 {
		dns := make([]netip.Addr, 0, len(params.DNS))
		for _, d := range params.DNS {
			if addr, err := netip.ParseAddr(d); err == nil {
				dns = append(dns, addr)
			}
		}
		hostCfg.DNS = dns
	}

	if params.Resources != nil {
		hostCfg.Resources = container.Resources{
			NanoCPUs: parseCPUs(params.Resources.CPUs),
			Memory:   parseMemory(params.Resources.Memory),
		}
	}

	resp, err := r.client.ContainerCreate(context.Background(), client.ContainerCreateOptions{
		Config:     cfg,
		HostConfig: hostCfg,
		Name:       params.Name,
	})
	if err != nil {
		return "", fmt.Errorf("container create: %w", err)
	}

	if _, err := r.client.ContainerStart(context.Background(), resp.ID, client.ContainerStartOptions{}); err != nil {
		return "", fmt.Errorf("container start: %w", err)
	}

	return resp.ID, nil
}

func (r *Runtime) ContainerStop(containerID string) error {
	_, err := r.client.ContainerStop(context.Background(), containerID, client.ContainerStopOptions{})
	return err
}

func (r *Runtime) ContainerRemove(containerID string, force bool) error {
	_, err := r.client.ContainerRemove(context.Background(), containerID, client.ContainerRemoveOptions{Force: force})
	return err
}

func (r *Runtime) ContainerInspect(containerID string) (*contracts.ContainerInfo, error) {
	resp, err := r.client.ContainerInspect(context.Background(), containerID, client.ContainerInspectOptions{})
	if err != nil {
		return nil, err
	}
	return toContainerInfo(&resp.Container), nil
}

func (r *Runtime) ContainerExec(containerID string, command []string) (string, error) {
	execResp, err := r.client.ExecCreate(context.Background(), containerID, client.ExecCreateOptions{
		Cmd:          command,
		AttachStdout: true,
		AttachStderr: true,
	})
	if err != nil {
		return "", fmt.Errorf("exec create: %w", err)
	}

	resp, err := r.client.ExecAttach(context.Background(), execResp.ID, client.ExecAttachOptions{})
	if err != nil {
		return "", fmt.Errorf("exec attach: %w", err)
	}
	defer resp.Close()

	output, err := io.ReadAll(resp.Reader)
	if err != nil {
		return "", fmt.Errorf("exec read: %w", err)
	}

	return strings.TrimSuffix(string(output), "\n"), nil
}

func (r *Runtime) ContainerLogs(containerID string, tail int) (string, error) {
	opts := client.ContainerLogsOptions{
		ShowStdout: true,
		ShowStderr: true,
	}
	if tail > 0 {
		opts.Tail = strconv.Itoa(tail)
	}

	reader, err := r.client.ContainerLogs(context.Background(), containerID, opts)
	if err != nil {
		return "", err
	}
	defer reader.Close()

	output, err := io.ReadAll(reader)
	if err != nil {
		return "", err
	}

	return strings.TrimSuffix(string(output), "\n"), nil
}

func (r *Runtime) ContainerList(all bool) ([]contracts.ContainerInfo, error) {
	containers, err := r.client.ContainerList(context.Background(), client.ContainerListOptions{All: all})
	if err != nil {
		return nil, err
	}

	result := make([]contracts.ContainerInfo, 0, len(containers.Items))
	for _, c := range containers.Items {
		result = append(result, *toContainerSummaryInfo(&c))
	}
	return result, nil
}

// ContainerUpdateLabels adds or updates labels on a running container without
// stopping or recreating it. Uses the Docker API's /containers/{id}/update
// endpoint which supports Labels since API v1.40.
func (r *Runtime) ContainerUpdateLabels(containerID string, labels map[string]string) error {
	payload := map[string]map[string]string{"Labels": labels}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal label payload: %w", err)
	}

	version := r.client.ClientVersion()
	apiPath := "/v" + strings.TrimPrefix(version, "v") + "/containers/" + containerID + "/update"

	// daemonHost may include scheme prefix (e.g. "http://docker" for unix sockets).
	// Construct the URL correctly in either case.
	host := r.daemonHost
	if !strings.HasPrefix(host, "http://") && !strings.HasPrefix(host, "https://") {
		host = "http://" + host
	}
	reqURL := host + apiPath

	req, err := http.NewRequestWithContext(context.Background(), "POST", reqURL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("update labels HTTP call: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("update labels failed (HTTP %d): %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}

	return nil
}

// ---------------------------------------------------------------------------
// Image operations
// ---------------------------------------------------------------------------

func (r *Runtime) PullImage(image string) error {
	resp, err := r.client.ImagePull(context.Background(), image, client.ImagePullOptions{})
	if err != nil {
		return err
	}
	defer resp.Close()
	// Consume the pull output to ensure the pull completes
	io.Copy(io.Discard, resp)
	return nil
}

func (r *Runtime) ImageList() ([]contracts.ImageInfo, error) {
	images, err := r.client.ImageList(context.Background(), client.ImageListOptions{})
	if err != nil {
		return nil, err
	}

	result := make([]contracts.ImageInfo, 0, len(images.Items))
	for _, img := range images.Items {
		result = append(result, *toImageInfo(&img))
	}
	return result, nil
}

// ---------------------------------------------------------------------------
// Network operations
// ---------------------------------------------------------------------------

func (r *Runtime) NetworkCreate(params contracts.NetworkCreateParams) (string, error) {
	netOpts := client.NetworkCreateOptions{
		Driver:     string(params.Driver),
		Internal:   params.Internal,
		Attachable: params.Attachable,
		Labels:     params.Labels,
	}

	// Build IPAM config if subnet/gateway/ip-range specified
	if params.Subnet != "" || params.Gateway != "" || params.IPRange != "" {
		ipamConfig := network.IPAMConfig{}
		if params.Subnet != "" {
			if p, err := netip.ParsePrefix(params.Subnet); err == nil {
				ipamConfig.Subnet = p
			}
		}
		if params.Gateway != "" {
			if a, err := netip.ParseAddr(params.Gateway); err == nil {
				ipamConfig.Gateway = a
			}
		}
		if params.IPRange != "" {
			if p, err := netip.ParsePrefix(params.IPRange); err == nil {
				ipamConfig.IPRange = p
			}
		}
		netOpts.IPAM = &network.IPAM{
			Config: []network.IPAMConfig{ipamConfig},
		}
	}

	resp, err := r.client.NetworkCreate(context.Background(), params.Name, netOpts)
	if err != nil {
		return "", err
	}

	return resp.ID, nil
}

func (r *Runtime) NetworkRemove(networkID string) error {
	_, err := r.client.NetworkRemove(context.Background(), networkID, client.NetworkRemoveOptions{})
	return err
}

func (r *Runtime) NetworkInspect(networkID string) (*contracts.NetworkInfo, error) {
	resp, err := r.client.NetworkInspect(context.Background(), networkID, client.NetworkInspectOptions{})
	if err != nil {
		return nil, err
	}
	return toNetworkInfo(&resp.Network.Network), nil
}

func (r *Runtime) NetworkList() ([]contracts.NetworkInfo, error) {
	nets, err := r.client.NetworkList(context.Background(), client.NetworkListOptions{})
	if err != nil {
		return nil, err
	}

	result := make([]contracts.NetworkInfo, 0, len(nets.Items))
	for _, n := range nets.Items {
		result = append(result, *toNetworkInfo(&n.Network))
	}
	return result, nil
}

func (r *Runtime) NetworkConnect(networkID string, containerID string) error {
	_, err := r.client.NetworkConnect(context.Background(), networkID, client.NetworkConnectOptions{
		Container: containerID,
	})
	return err
}

// ---------------------------------------------------------------------------
// Volume operations
// ---------------------------------------------------------------------------

func (r *Runtime) VolumeCreate(params contracts.VolumeCreateParams) (string, error) {
	vol, err := r.client.VolumeCreate(context.Background(), client.VolumeCreateOptions{
		Name:   params.Name,
		Driver: params.Driver,
		Labels: params.Labels,
	})
	if err != nil {
		return "", err
	}
	return vol.Volume.Name, nil
}

func (r *Runtime) VolumeRemove(volumeID string, force bool) error {
	_, err := r.client.VolumeRemove(context.Background(), volumeID, client.VolumeRemoveOptions{Force: force})
	return err
}

func (r *Runtime) VolumeInspect(volumeID string) (*contracts.VolumeInfo, error) {
	vol, err := r.client.VolumeInspect(context.Background(), volumeID, client.VolumeInspectOptions{})
	if err != nil {
		return nil, err
	}
	return toVolumeInfo(&vol.Volume), nil
}

func (r *Runtime) VolumeList() ([]contracts.VolumeInfo, error) {
	vols, err := r.client.VolumeList(context.Background(), client.VolumeListOptions{})
	if err != nil {
		return nil, err
	}

	result := make([]contracts.VolumeInfo, 0, len(vols.Items))
	for _, v := range vols.Items {
		result = append(result, *toVolumeInfo(&v))
	}
	return result, nil
}

// ---------------------------------------------------------------------------
// Info / Ping
// ---------------------------------------------------------------------------

func (r *Runtime) Ping() error {
	_, err := r.client.Ping(context.Background(), client.PingOptions{})
	return err
}

func (r *Runtime) Info() (*contracts.RuntimeInfo, error) {
	dockerInfo, err := r.client.Info(context.Background(), client.InfoOptions{})
	if err != nil {
		return nil, err
	}
	return toRuntimeInfo(&dockerInfo.Info), nil
}

// ---------------------------------------------------------------------------
// TLS config builder
// ---------------------------------------------------------------------------

func buildTLSConfig(tlsCfg *contracts.TLSConfig) (*tls.Config, error) {
	tlsConfig := &tls.Config{
		InsecureSkipVerify: tlsCfg.SkipVerify,
	}

	if tlsCfg.CACert != "" {
		caPool := x509.NewCertPool()
		if !caPool.AppendCertsFromPEM([]byte(tlsCfg.CACert)) {
			return nil, fmt.Errorf("failed to parse CA certificate")
		}
		tlsConfig.RootCAs = caPool
	}

	if tlsCfg.Cert != "" && tlsCfg.Key != "" {
		cert, err := tls.X509KeyPair([]byte(tlsCfg.Cert), []byte(tlsCfg.Key))
		if err != nil {
			return nil, fmt.Errorf("parse TLS key pair: %w", err)
		}
		tlsConfig.Certificates = []tls.Certificate{cert}
	}

	return tlsConfig, nil
}

// ---------------------------------------------------------------------------
// Type conversion helpers
// ---------------------------------------------------------------------------

func toContainerInfo(resp *container.InspectResponse) *contracts.ContainerInfo {
	info := &contracts.ContainerInfo{
		ID:      resp.ID,
		Name:    strings.TrimPrefix(resp.Name, "/"),
		Image:   resp.Image,
		CreatedAt: resp.Created,
	}
	if resp.State != nil {
		info.State = string(resp.State.Status)
		info.Status = string(resp.State.Status)
		if resp.State.Health != nil {
			info.Status = string(resp.State.Health.Status)
		}
	}

	// Config
	if resp.Config != nil {
		info.Labels = resp.Config.Labels
		info.Env = toEnvMap(resp.Config.Env)
		info.Command = resp.Config.Cmd
		info.Entrypoint = resp.Config.Entrypoint
		info.User = resp.Config.User
		info.WorkingDir = resp.Config.WorkingDir
		info.Hostname = resp.Config.Hostname
		info.Tty = resp.Config.Tty
		if resp.Config.Healthcheck != nil {
			info.Healthcheck = &contracts.HealthcheckConfig{
				Test:        resp.Config.Healthcheck.Test,
				Interval:    resp.Config.Healthcheck.Interval.String(),
				Timeout:     resp.Config.Healthcheck.Timeout.String(),
				Retries:     resp.Config.Healthcheck.Retries,
				StartPeriod: resp.Config.Healthcheck.StartPeriod.String(),
			}
		}
	}

	// Host config
	if resp.HostConfig != nil {
		info.Privileged = resp.HostConfig.Privileged
		info.CapAdd = resp.HostConfig.CapAdd
		info.CapDrop = resp.HostConfig.CapDrop
		info.Sysctls = resp.HostConfig.Sysctls
		info.ExtraHosts = resp.HostConfig.ExtraHosts
		info.NetworkMode = string(resp.HostConfig.NetworkMode)
		if resp.HostConfig.RestartPolicy.Name != "" {
			info.RestartPolicy = string(resp.HostConfig.RestartPolicy.Name)
		}
		if len(resp.HostConfig.DNS) > 0 {
			dns := make([]string, len(resp.HostConfig.DNS))
			for i, addr := range resp.HostConfig.DNS {
				dns[i] = addr.String()
			}
			info.DNS = dns
		}
		if len(resp.HostConfig.DNSSearch) > 0 {
			info.DNSSearch = resp.HostConfig.DNSSearch
		}
		if len(resp.HostConfig.Devices) > 0 {
			info.Devices = make([]contracts.DeviceMapping, 0, len(resp.HostConfig.Devices))
			for _, d := range resp.HostConfig.Devices {
				info.Devices = append(info.Devices, contracts.DeviceMapping{
					HostPath:      d.PathOnHost,
					ContainerPath: d.PathInContainer,
					Permissions:   d.CgroupPermissions,
				})
			}
		}
		if resp.HostConfig.Memory > 0 || resp.HostConfig.NanoCPUs > 0 {
			info.Resources = &contracts.ResourceLimits{}
			if resp.HostConfig.NanoCPUs > 0 {
				info.Resources.CPUs = fmt.Sprintf("%.2f", float64(resp.HostConfig.NanoCPUs)/1e9)
			}
			if resp.HostConfig.Memory > 0 {
				info.Resources.Memory = fmt.Sprintf("%d", resp.HostConfig.Memory)
			}
		}
	}

	// Network settings
	if resp.NetworkSettings != nil && len(resp.NetworkSettings.Networks) > 0 {
		info.Networks = make(map[string]string, len(resp.NetworkSettings.Networks))
		for name, ns := range resp.NetworkSettings.Networks {
			info.Networks[name] = ns.IPAddress.String()
		}
	}

	// Mounts
	if len(resp.Mounts) > 0 {
		info.Mounts = make([]contracts.VolumeMount, 0, len(resp.Mounts))
		for _, m := range resp.Mounts {
			info.Mounts = append(info.Mounts, contracts.VolumeMount{
				Source:   m.Source,
				Target:   m.Destination,
				ReadOnly: !m.RW,
				Type:     string(m.Type),
			})
		}
	}

	return info
}

// toEnvMap converts Docker's ["KEY=value", ...] format to map[string]string.
func toEnvMap(env []string) map[string]string {
	if len(env) == 0 {
		return nil
	}
	m := make(map[string]string, len(env))
	for _, e := range env {
		if idx := strings.Index(e, "="); idx > 0 {
			m[e[:idx]] = e[idx+1:]
		}
	}
	return m
}

func toContainerSummaryInfo(c *container.Summary) *contracts.ContainerInfo {
	info := &contracts.ContainerInfo{
		ID:      c.ID,
		Image:   c.Image,
		Status:  c.Status,
		State:   string(c.State),
		CreatedAt: timeStr(c.Created),
		Labels:  c.Labels,
	}

	if len(c.Names) > 0 {
		info.Name = strings.TrimPrefix(c.Names[0], "/")
	}

	// Ports
	if len(c.Ports) > 0 {
		info.Ports = make([]contracts.PortMapping, 0, len(c.Ports))
		for _, p := range c.Ports {
			info.Ports = append(info.Ports, contracts.PortMapping{
				HostPort:      int(p.PublicPort),
				ContainerPort: int(p.PrivatePort),
				Protocol:      p.Type,
			})
		}
	}

	// Networks
	if c.NetworkSettings != nil && len(c.NetworkSettings.Networks) > 0 {
		info.Networks = make(map[string]string)
		for name, settings := range c.NetworkSettings.Networks {
			info.Networks[name] = settings.IPAddress.String()
		}
	}

	// Mounts
	if len(c.Mounts) > 0 {
		info.Mounts = make([]contracts.VolumeMount, 0, len(c.Mounts))
		for _, m := range c.Mounts {
			mount := contracts.VolumeMount{
				Source:   m.Source,
				Target:   m.Destination,
				ReadOnly: !m.RW,
			}
			if m.Type != "" {
				mount.Type = string(m.Type)
			}
			info.Mounts = append(info.Mounts, mount)
		}
	}

	return info
}

func toImageInfo(img *image.Summary) *contracts.ImageInfo {
	return &contracts.ImageInfo{
		ID:        img.ID,
		RepoTags:  img.RepoTags,
		CreatedAt: timeStr(img.Created),
		Size:      img.Size,
		Labels:    img.Labels,
	}
}

func toNetworkInfo(n *network.Network) *contracts.NetworkInfo {
	info := &contracts.NetworkInfo{
		ID:       n.ID,
		Name:     n.Name,
		Driver:   n.Driver,
		Internal: n.Internal,
		Scope:    n.Scope,
		Labels:   n.Labels,
	}

	if n.IPAM.Config != nil && len(n.IPAM.Config) > 0 {
		info.Subnet = n.IPAM.Config[0].Subnet.String()
		info.Gateway = n.IPAM.Config[0].Gateway.String()
	}

	return info
}

func toVolumeInfo(v *volume.Volume) *contracts.VolumeInfo {
	info := &contracts.VolumeInfo{
		Name:       v.Name,
		Driver:     v.Driver,
		Mountpoint: v.Mountpoint,
		CreatedAt:  v.CreatedAt,
		Labels:     v.Labels,
	}
	if v.UsageData != nil {
		info.Size = v.UsageData.Size
	}
	return info
}

func toRuntimeInfo(dockerInfo *system.Info) *contracts.RuntimeInfo {
	return &contracts.RuntimeInfo{
		Engine:     contracts.EngineTypeDocker,
		Version:    dockerInfo.ServerVersion,
		APIVersion: dockerInfo.ServerVersion, // SDK negotiates version
		OS:         dockerInfo.OSType,
		Arch:       dockerInfo.Architecture,
		Name:       dockerInfo.Name,
	}
}

// ---------------------------------------------------------------------------
// Utility functions
// ---------------------------------------------------------------------------

func timeStr(ts int64) string {
	if ts == 0 {
		return ""
	}
	return time.Unix(ts, 0).Format(time.RFC3339)
}

func mapToEnvSlice(env map[string]string) []string {
	if len(env) == 0 {
		return nil
	}
	result := make([]string, 0, len(env))
	for k, v := range env {
		result = append(result, k+"="+v)
	}
	return result
}

func mapRestartPolicy(policy contracts.RestartPolicy) container.RestartPolicyMode {
	switch policy {
	case contracts.RestartPolicyNo:
		return container.RestartPolicyDisabled
	case contracts.RestartPolicyAlways:
		return container.RestartPolicyAlways
	case contracts.RestartPolicyOnFailure:
		return container.RestartPolicyOnFailure
	case contracts.RestartPolicyUnlessStopped:
		return container.RestartPolicyUnlessStopped
	default:
		return container.RestartPolicyDisabled
	}
}

func mapPortBindings(ports []contracts.PortMapping) network.PortMap {
	if len(ports) == 0 {
		return nil
	}
	portMap := make(network.PortMap)
	for _, p := range ports {
		proto := network.IPProtocol(p.Protocol)
		if proto == "" {
			proto = network.TCP
		}
		portStr := strconv.Itoa(p.ContainerPort) + "/" + string(proto)
		port, err := network.ParsePort(portStr)
		if err != nil {
			continue
		}
		portMap[port] = []network.PortBinding{
			{HostPort: strconv.Itoa(p.HostPort)},
		}
	}
	return portMap
}

func mapVolumeBinds(volumes []contracts.VolumeMount) []string {
	if len(volumes) == 0 {
		return nil
	}
	binds := make([]string, 0, len(volumes))
	for _, v := range volumes {
		bind := v.Source + ":" + v.Target
		if v.ReadOnly {
			bind += ":ro"
		}
		binds = append(binds, bind)
	}
	return binds
}

func mapDevices(devices []contracts.DeviceMapping) []container.DeviceMapping {
	if len(devices) == 0 {
		return nil
	}
	result := make([]container.DeviceMapping, 0, len(devices))
	for _, d := range devices {
		result = append(result, container.DeviceMapping{
			PathOnHost:        d.HostPath,
			PathInContainer:   d.ContainerPath,
			CgroupPermissions: d.Permissions,
		})
	}
	return result
}

func parseCPUs(cpus string) int64 {
	if cpus == "" {
		return 0
	}
	// Parse float CPUs to nano CPUs (e.g., "1.5" → 1.5 * 1e9)
	f, err := strconv.ParseFloat(cpus, 64)
	if err != nil {
		return 0
	}
	return int64(f * 1e9)
}

func parseMemory(memory string) int64 {
	if memory == "" {
		return 0
	}
	// Parse memory strings like "512m", "2g"
	// For simplicity, try direct int64 parse first, then fall back
	if mem, err := strconv.ParseInt(memory, 10, 64); err == nil {
		return mem
	}
	return 0
}
