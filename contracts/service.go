package contracts

type ServiceDefinition struct {
	APIVersion   string              `yaml:"api_version" json:"api_version"`
	Name         string              `yaml:"name" json:"name"`
	Description  string              `yaml:"description,omitempty" json:"description,omitempty"`
	Image        string              `yaml:"image,omitempty" json:"image,omitempty"`
	Params       []*ParamDef         `yaml:"params,omitempty" json:"params,omitempty"`
	Init         *InitConfig         `yaml:"init,omitempty" json:"init,omitempty"`
	Container    *ContainerConfig    `yaml:"container,omitempty" json:"container,omitempty"`
	Traefik      *TraefikConfig      `yaml:"traefik,omitempty" json:"traefik,omitempty"`
	Dependencies []string            `yaml:"dependencies,omitempty" json:"dependencies,omitempty"`
	PostInstall  []*PostInstallHook  `yaml:"post_install,omitempty" json:"post_install,omitempty"`
	Category     string              `yaml:"category,omitempty" json:"category,omitempty"`
	Tags         []string            `yaml:"tags,omitempty" json:"tags,omitempty"`
}

type InitConfig struct {
	PreExec    []*ExecStep     `yaml:"pre_exec,omitempty" json:"pre_exec,omitempty"`
	Containers []*InitContainer `yaml:"containers,omitempty" json:"containers,omitempty"`
	WaitFor    *WaitCondition  `yaml:"wait_for,omitempty" json:"wait_for,omitempty"`
}

type ExecStep struct {
	Command     []string          `yaml:"command" json:"command"`
	Env         map[string]string `yaml:"env,omitempty" json:"env,omitempty"`
	WorkDir     string            `yaml:"work_dir,omitempty" json:"work_dir,omitempty"`
	IgnoreError bool              `yaml:"ignore_error,omitempty" json:"ignore_error,omitempty"`
}

type InitContainer struct {
	Name       string            `yaml:"name" json:"name"`
	Image      string            `yaml:"image" json:"image"`
	Command    []string          `yaml:"command,omitempty" json:"command,omitempty"`
	Entrypoint []string          `yaml:"entrypoint,omitempty" json:"entrypoint,omitempty"`
	Volumes    []VolumeMount     `yaml:"volumes,omitempty" json:"volumes,omitempty"`
	Environment map[string]string `yaml:"environment,omitempty" json:"environment,omitempty"`
	Networks   []string          `yaml:"networks,omitempty" json:"networks,omitempty"`
	User       string            `yaml:"user,omitempty" json:"user,omitempty"`
	Privileged bool              `yaml:"privileged,omitempty" json:"privileged,omitempty"`
	WaitExit   bool              `yaml:"wait_exit,omitempty" json:"wait_exit,omitempty"`
	IgnoreError bool             `yaml:"ignore_error,omitempty" json:"ignore_error,omitempty"`
}

type WaitType string

const (
	WaitTypeHTTP     WaitType = "http"
	WaitTypeTCP      WaitType = "tcp"
	WaitTypeLog      WaitType = "log"
	WaitTypeExitCode WaitType = "exit_code"
)

type WaitCondition struct {
	Type      WaitType `yaml:"type" json:"type"`
	Target    string   `yaml:"target,omitempty" json:"target,omitempty"`
	Timeout   string   `yaml:"timeout,omitempty" json:"timeout,omitempty"`
	Interval  string   `yaml:"interval,omitempty" json:"interval,omitempty"`
	Pattern   string   `yaml:"pattern,omitempty" json:"pattern,omitempty"`
	Retries   int      `yaml:"retries,omitempty" json:"retries,omitempty"`
}

type ContainerConfig struct {
	Image         string            `yaml:"image" json:"image"`
	Name          string            `yaml:"name,omitempty" json:"name,omitempty"`
	Command       []string          `yaml:"command,omitempty" json:"command,omitempty"`
	Entrypoint    []string          `yaml:"entrypoint,omitempty" json:"entrypoint,omitempty"`
	Env           map[string]string `yaml:"env,omitempty" json:"env,omitempty"`
	EnvFile       string            `yaml:"env_file,omitempty" json:"env_file,omitempty"`
	Ports         []PortMapping     `yaml:"ports,omitempty" json:"ports,omitempty"`
	Volumes       []VolumeMount     `yaml:"volumes,omitempty" json:"volumes,omitempty"`
	Devices       []DeviceMapping   `yaml:"devices,omitempty" json:"devices,omitempty"`
	NetworkMode   string            `yaml:"network_mode,omitempty" json:"network_mode,omitempty"`
	Networks      []string          `yaml:"networks,omitempty" json:"networks,omitempty"`
	RestartPolicy RestartPolicy     `yaml:"restart_policy,omitempty" json:"restart_policy,omitempty"`
	Privileged    bool              `yaml:"privileged,omitempty" json:"privileged,omitempty"`
	CapAdd        []string          `yaml:"cap_add,omitempty" json:"cap_add,omitempty"`
	CapDrop       []string          `yaml:"cap_drop,omitempty" json:"cap_drop,omitempty"`
	Sysctls       map[string]string `yaml:"sysctls,omitempty" json:"sysctls,omitempty"`
	User          string            `yaml:"user,omitempty" json:"user,omitempty"`
	GroupAdd      []string          `yaml:"group_add,omitempty" json:"group_add,omitempty"`
	Healthcheck   *HealthcheckDef   `yaml:"healthcheck,omitempty" json:"healthcheck,omitempty"`
	Resources     *ResourceDef      `yaml:"resources,omitempty" json:"resources,omitempty"`
	Labels        map[string]string `yaml:"labels,omitempty" json:"labels,omitempty"`
	ExtraHosts    []string          `yaml:"extra_hosts,omitempty" json:"extra_hosts,omitempty"`
	DNS           []string          `yaml:"dns,omitempty" json:"dns,omitempty"`
	DNSSearch     []string          `yaml:"dns_search,omitempty" json:"dns_search,omitempty"`
	ShmSize       string            `yaml:"shm_size,omitempty" json:"shm_size,omitempty"`
	StopTimeout   string            `yaml:"stop_timeout,omitempty" json:"stop_timeout,omitempty"`
	StopSignal    string            `yaml:"stop_signal,omitempty" json:"stop_signal,omitempty"`
	Hostname      string            `yaml:"hostname,omitempty" json:"hostname,omitempty"`
	Domainname    string            `yaml:"domainname,omitempty" json:"domainname,omitempty"`
	MacAddress    string            `yaml:"mac_address,omitempty" json:"mac_address,omitempty"`
	ReadOnly      bool              `yaml:"read_only,omitempty" json:"read_only,omitempty"`
	Init          bool              `yaml:"init,omitempty" json:"init,omitempty"`
	Tmpfs         []string          `yaml:"tmpfs,omitempty" json:"tmpfs,omitempty"`
	Secrets       []string          `yaml:"secrets,omitempty" json:"secrets,omitempty"`
	Configs       []string          `yaml:"configs,omitempty" json:"configs,omitempty"`
	LogDriver     string            `yaml:"log_driver,omitempty" json:"log_driver,omitempty"`
	LogOpts       map[string]string `yaml:"log_opts,omitempty" json:"log_opts,omitempty"`
}

type TraefikConfig struct {
	Enabled      bool                        `yaml:"enabled" json:"enabled"`
	Entrypoint   string                      `yaml:"entrypoint,omitempty" json:"entrypoint,omitempty"`
	Host         string                      `yaml:"host,omitempty" json:"host,omitempty"`
	TLS          bool                        `yaml:"tls,omitempty" json:"tls,omitempty"`
	CertResolver string                      `yaml:"cert_resolver,omitempty" json:"cert_resolver,omitempty"`
	Middlewares  []string                    `yaml:"middlewares,omitempty" json:"middlewares,omitempty"`
	Auth         *TraefikAuthConfig          `yaml:"auth,omitempty" json:"auth,omitempty"`
	NetworkMode  string                      `yaml:"network_mode,omitempty" json:"network_mode,omitempty"`
	LoadBalancer *LoadBalancerDef            `yaml:"load_balancer,omitempty" json:"load_balancer,omitempty"`
	ExtraLabels  map[string]string           `yaml:"extra_labels,omitempty" json:"extra_labels,omitempty"`
	Routers      []*TraefikRouterDef         `yaml:"routers,omitempty" json:"routers,omitempty"`
}

type TraefikRouterDef struct {
	Name        string   `yaml:"name" json:"name"`
	Entrypoint  string   `yaml:"entrypoint,omitempty" json:"entrypoint,omitempty"`
	Host        string   `yaml:"host,omitempty" json:"host,omitempty"`
	TLS         bool     `yaml:"tls,omitempty" json:"tls,omitempty"`
	Middlewares []string `yaml:"middlewares,omitempty" json:"middlewares,omitempty"`
	Priority    int      `yaml:"priority,omitempty" json:"priority,omitempty"`
}

type TraefikAuthConfig struct {
	BasicAuth   *BasicAuthConfig   `yaml:"basic_auth,omitempty" json:"basic_auth,omitempty"`
	DigestAuth  *DigestAuthConfig  `yaml:"digest_auth,omitempty" json:"digest_auth,omitempty"`
	ForwardAuth *ForwardAuthConfig `yaml:"forward_auth,omitempty" json:"forward_auth,omitempty"`
}

type BasicAuthConfig struct {
	Users      []string `yaml:"users" json:"users"`
	Realm      string   `yaml:"realm,omitempty" json:"realm,omitempty"`
	RemoveHeader bool   `yaml:"remove_header,omitempty" json:"remove_header,omitempty"`
}

type DigestAuthConfig struct {
	Users       []string `yaml:"users" json:"users"`
	RemoveHeader bool    `yaml:"remove_header,omitempty" json:"remove_header,omitempty"`
}

type ForwardAuthConfig struct {
	Address            string `yaml:"address" json:"address"`
	TrustForwardHeader bool   `yaml:"trust_forward_header,omitempty" json:"trust_forward_header,omitempty"`
	AuthResponseHeaders map[string]string `yaml:"auth_response_headers,omitempty" json:"auth_response_headers,omitempty"`
}

type LoadBalancerDef struct {
	Servers         []string          `yaml:"servers,omitempty" json:"servers,omitempty"`
	Port            int               `yaml:"port,omitempty" json:"port,omitempty"`
	Scheme          string            `yaml:"scheme,omitempty" json:"scheme,omitempty"`
	Sticky          bool              `yaml:"sticky,omitempty" json:"sticky,omitempty"`
	PassHostHeader  bool              `yaml:"pass_host_header,omitempty" json:"pass_host_header,omitempty"`
	HealthCheck     *HealthcheckDef   `yaml:"health_check,omitempty" json:"health_check,omitempty"`
}

type PostInstallHook struct {
	Type    string   `yaml:"type" json:"type"`
	Command []string `yaml:"command,omitempty" json:"command,omitempty"`
	URL     string   `yaml:"url,omitempty" json:"url,omitempty"`
	Message string   `yaml:"message,omitempty" json:"message,omitempty"`
}

type HealthcheckDef struct {
	Test         []string `yaml:"test" json:"test"`
	Interval     string   `yaml:"interval,omitempty" json:"interval,omitempty"`
	Timeout      string   `yaml:"timeout,omitempty" json:"timeout,omitempty"`
	Retries      int      `yaml:"retries,omitempty" json:"retries,omitempty"`
	StartPeriod  string   `yaml:"start_period,omitempty" json:"start_period,omitempty"`
}

type ResourceDef struct {
	CPUs   string `yaml:"cpus,omitempty" json:"cpus,omitempty"`
	Memory string `yaml:"memory,omitempty" json:"memory,omitempty"`
}

type ServiceStatus string

const (
	ServiceStatusInstalled    ServiceStatus = "installed"
	ServiceStatusNotInstalled ServiceStatus = "not_installed"
	ServiceStatusRunning      ServiceStatus = "running"
	ServiceStatusStopped      ServiceStatus = "stopped"
	ServiceStatusError        ServiceStatus = "error"
	ServiceStatusUnknown      ServiceStatus = "unknown"
)

type ServiceStatusResult struct {
	Name   string        `json:"name"`
	Status ServiceStatus `json:"status"`
}

type ServiceManager interface {
	List() ([]*ServiceDefinition, error)
	Get(name string) (*ServiceDefinition, error)
	GetByCategory(category string) ([]*ServiceDefinition, error)
	Search(query string) ([]*ServiceDefinition, error)
	Install(name string, params []*ParamValue, remote string) (string, error)
	Uninstall(name string) error
	Status(name string) (*ServiceStatusResult, error)
	Restart(name string) error
	Update(name string) error
	PreCheck(name string, params []*ParamValue) error
	RenderConfig(name string, params []*ParamValue) (map[string]string, error)
}
