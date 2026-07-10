package contracts

type ConnectionType string

const (
	ConnectionTypeUnix  ConnectionType = "unix"
	ConnectionTypeTCP   ConnectionType = "tcp"
	ConnectionTypeHTTPS ConnectionType = "https"
	ConnectionTypeSSH   ConnectionType = "ssh"
)

type EngineType string

const (
	EngineTypeDocker EngineType = "docker"
	EngineTypePodman EngineType = "podman"
	EngineTypeAuto   EngineType = "auto"
)

type RestartPolicy string

const (
	RestartPolicyNo            RestartPolicy = "no"
	RestartPolicyAlways        RestartPolicy = "always"
	RestartPolicyOnFailure     RestartPolicy = "on-failure"
	RestartPolicyUnlessStopped RestartPolicy = "unless-stopped"
)

type NetworkDriver string

const (
	NetworkDriverBridge   NetworkDriver = "bridge"
	NetworkDriverHost     NetworkDriver = "host"
	NetworkDriverOverlay  NetworkDriver = "overlay"
	NetworkDriverMacvlan  NetworkDriver = "macvlan"
	NetworkDriverNone     NetworkDriver = "none"
)

type TLSConfig struct {
	Enabled    bool   `yaml:"enabled" json:"enabled"`
	CACert     string `yaml:"ca_cert" json:"ca_cert"`
	Cert       string `yaml:"cert" json:"cert"`
	Key        string `yaml:"key" json:"key"`
	SkipVerify bool   `yaml:"skip_verify" json:"skip_verify"`
}

type ConnectionConfig struct {
	Type       ConnectionType `yaml:"type" json:"type"`
	Endpoint   string         `yaml:"endpoint" json:"endpoint"`
	Engine     EngineType     `yaml:"engine,omitempty" json:"engine,omitempty"`
	TLS        *TLSConfig     `yaml:"tls,omitempty" json:"tls,omitempty"`
	SSHKeyPath string         `yaml:"ssh_key_path,omitempty" json:"ssh_key_path,omitempty"`
	SSHUser    string         `yaml:"ssh_user,omitempty" json:"ssh_user,omitempty"`
}

type PortMapping struct {
	HostPort      int    `yaml:"host_port" json:"host_port"`
	ContainerPort int    `yaml:"container_port" json:"container_port"`
	Protocol      string `yaml:"protocol,omitempty" json:"protocol,omitempty"`
}

type VolumeMount struct {
	Source   string `yaml:"source" json:"source"`
	Target   string `yaml:"target" json:"target"`
	ReadOnly bool   `yaml:"read_only,omitempty" json:"read_only,omitempty"`
	Type     string `yaml:"type,omitempty" json:"type,omitempty"`
}

type DeviceMapping struct {
	HostPath      string `yaml:"host_path" json:"host_path"`
	ContainerPath string `yaml:"container_path" json:"container_path"`
	Permissions   string `yaml:"permissions,omitempty" json:"permissions,omitempty"`
}

type ContainerRunParams struct {
	Image         string            `yaml:"image" json:"image"`
	Name          string            `yaml:"name,omitempty" json:"name,omitempty"`
	Command       []string          `yaml:"command,omitempty" json:"command,omitempty"`
	Entrypoint    []string          `yaml:"entrypoint,omitempty" json:"entrypoint,omitempty"`
	Env           map[string]string `yaml:"env,omitempty" json:"env,omitempty"`
	Ports         []PortMapping     `yaml:"ports,omitempty" json:"ports,omitempty"`
	Volumes       []VolumeMount     `yaml:"volumes,omitempty" json:"volumes,omitempty"`
	Devices       []DeviceMapping   `yaml:"devices,omitempty" json:"devices,omitempty"`
	NetworkMode   string            `yaml:"network_mode,omitempty" json:"network_mode,omitempty"`
	RestartPolicy RestartPolicy     `yaml:"restart_policy,omitempty" json:"restart_policy,omitempty"`
	Privileged    bool              `yaml:"privileged,omitempty" json:"privileged,omitempty"`
	User          string            `yaml:"user,omitempty" json:"user,omitempty"`
	Labels        map[string]string `yaml:"labels,omitempty" json:"labels,omitempty"`
	CapAdd        []string          `yaml:"cap_add,omitempty" json:"cap_add,omitempty"`
	CapDrop       []string          `yaml:"cap_drop,omitempty" json:"cap_drop,omitempty"`
	Sysctls       map[string]string `yaml:"sysctls,omitempty" json:"sysctls,omitempty"`
	Healthcheck   *HealthcheckConfig `yaml:"healthcheck,omitempty" json:"healthcheck,omitempty"`
	Resources     *ResourceLimits   `yaml:"resources,omitempty" json:"resources,omitempty"`
	ExtraHosts    []string          `yaml:"extra_hosts,omitempty" json:"extra_hosts,omitempty"`
	DNS           []string          `yaml:"dns,omitempty" json:"dns,omitempty"`
	DNSSearch     []string          `yaml:"dns_search,omitempty" json:"dns_search,omitempty"`
	NetworkAliases []string         `yaml:"network_aliases,omitempty" json:"network_aliases,omitempty"`
}

type ContainerInfo struct {
	ID        string            `yaml:"id" json:"id"`
	Name      string            `yaml:"name" json:"name"`
	Image     string            `yaml:"image" json:"image"`
	Status    string            `yaml:"status" json:"status"`
	State     string            `yaml:"state" json:"state"`
	CreatedAt string            `yaml:"created_at" json:"created_at"`
	Ports     []PortMapping     `yaml:"ports,omitempty" json:"ports,omitempty"`
	Networks  map[string]string `yaml:"networks,omitempty" json:"networks,omitempty"`
	Labels    map[string]string `yaml:"labels,omitempty" json:"labels,omitempty"`
	Mounts    []VolumeMount     `yaml:"mounts,omitempty" json:"mounts,omitempty"`
}

type ImageInfo struct {
	ID        string            `yaml:"id" json:"id"`
	RepoTags  []string          `yaml:"repo_tags" json:"repo_tags"`
	CreatedAt string            `yaml:"created_at" json:"created_at"`
	Size      int64             `yaml:"size" json:"size"`
	Labels    map[string]string `yaml:"labels,omitempty" json:"labels,omitempty"`
}

type NetworkCreateParams struct {
	Name       string         `yaml:"name" json:"name"`
	Driver     NetworkDriver  `yaml:"driver,omitempty" json:"driver,omitempty"`
	Internal   bool           `yaml:"internal,omitempty" json:"internal,omitempty"`
	Attachable bool           `yaml:"attachable,omitempty" json:"attachable,omitempty"`
	Labels     map[string]string `yaml:"labels,omitempty" json:"labels,omitempty"`
	Subnet     string         `yaml:"subnet,omitempty" json:"subnet,omitempty"`
	Gateway    string         `yaml:"gateway,omitempty" json:"gateway,omitempty"`
	IPRange    string         `yaml:"ip_range,omitempty" json:"ip_range,omitempty"`
}

type NetworkInfo struct {
	ID        string            `yaml:"id" json:"id"`
	Name      string            `yaml:"name" json:"name"`
	Driver    string            `yaml:"driver" json:"driver"`
	Internal  bool              `yaml:"internal" json:"internal"`
	Scope     string            `yaml:"scope,omitempty" json:"scope,omitempty"`
	Subnet    string            `yaml:"subnet,omitempty" json:"subnet,omitempty"`
	Gateway   string            `yaml:"gateway,omitempty" json:"gateway,omitempty"`
	Labels    map[string]string `yaml:"labels,omitempty" json:"labels,omitempty"`
}

type VolumeCreateParams struct {
	Name       string            `yaml:"name" json:"name"`
	Driver     string            `yaml:"driver,omitempty" json:"driver,omitempty"`
	Labels     map[string]string `yaml:"labels,omitempty" json:"labels,omitempty"`
}

type VolumeInfo struct {
	Name       string            `yaml:"name" json:"name"`
	Driver     string            `yaml:"driver" json:"driver"`
	Mountpoint string            `yaml:"mountpoint" json:"mountpoint"`
	CreatedAt  string            `yaml:"created_at" json:"created_at"`
	Labels     map[string]string `yaml:"labels,omitempty" json:"labels,omitempty"`
	Size       int64             `yaml:"size,omitempty" json:"size,omitempty"`
}

type HealthcheckConfig struct {
	Test         []string `yaml:"test" json:"test"`
	Interval     string   `yaml:"interval,omitempty" json:"interval,omitempty"`
	Timeout      string   `yaml:"timeout,omitempty" json:"timeout,omitempty"`
	Retries      int      `yaml:"retries,omitempty" json:"retries,omitempty"`
	StartPeriod  string   `yaml:"start_period,omitempty" json:"start_period,omitempty"`
}

type ResourceLimits struct {
	CPUs   string `yaml:"cpus,omitempty" json:"cpus,omitempty"`
	Memory string `yaml:"memory,omitempty" json:"memory,omitempty"`
}

type RuntimeInfo struct {
	Engine     EngineType `yaml:"engine" json:"engine"`
	Version    string     `yaml:"version" json:"version"`
	APIVersion string     `yaml:"api_version" json:"api_version"`
	OS         string     `yaml:"os" json:"os"`
	Arch       string     `yaml:"arch" json:"arch"`
	Name       string     `yaml:"name" json:"name"`
}

type ContainerRuntime interface {
	ContainerRun(params ContainerRunParams) (string, error)
	ContainerStop(containerID string) error
	ContainerRemove(containerID string, force bool) error
	ContainerInspect(containerID string) (*ContainerInfo, error)
	ContainerExec(containerID string, command []string) (string, error)
	ContainerLogs(containerID string, tail int) (string, error)
	ContainerList(all bool) ([]ContainerInfo, error)
	PullImage(image string) error
	ImageList() ([]ImageInfo, error)
	NetworkCreate(params NetworkCreateParams) (string, error)
	NetworkRemove(networkID string) error
	NetworkInspect(networkID string) (*NetworkInfo, error)
	NetworkList() ([]NetworkInfo, error)
	NetworkConnect(networkID string, containerID string) error
	VolumeCreate(params VolumeCreateParams) (string, error)
	VolumeRemove(volumeID string, force bool) error
	VolumeInspect(volumeID string) (*VolumeInfo, error)
	VolumeList() ([]VolumeInfo, error)
	Ping() error
	Info() (*RuntimeInfo, error)
}

type RuntimeFactory interface {
	Create(config ConnectionConfig) (ContainerRuntime, error)
	Detect() (ContainerRuntime, error)
}
