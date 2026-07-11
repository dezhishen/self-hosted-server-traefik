package contracts

type AuthConfig struct {
	Username     string `yaml:"username" json:"username"`
	PasswordHash string `yaml:"password_hash" json:"-"`
}

type SystemConfig struct {
	BaseDataDir string      `yaml:"base_data_dir,omitempty" json:"base_data_dir,omitempty"`
	Auth        *AuthConfig `yaml:"auth,omitempty" json:"auth,omitempty"`
}

type EndpointCollection struct {
	Endpoints map[string]*EndpointConfig `yaml:"endpoints" json:"endpoints"`
}

type AppConfig struct {
	BaseDataDir   string                     `yaml:"base_data_dir,omitempty" json:"base_data_dir,omitempty"`
	Auth          *AuthConfig                `yaml:"auth,omitempty" json:"auth,omitempty"`
	Endpoints     map[string]*EndpointConfig  `yaml:"endpoints" json:"endpoints"`
	Subscriptions []Subscription            `yaml:"subscriptions,omitempty" json:"subscriptions,omitempty"`
}

type EndpointConfig struct {
	Name       string            `yaml:"name" json:"name"`
	Connection *ConnectionConfig `yaml:"connection" json:"connection"`
	Default    bool              `yaml:"default" json:"default"`
}

type ConfigStore interface {
	Get(key string) (interface{}, error)
	Set(key string, value interface{}) error
	GetAll() (map[string]interface{}, error)
	Delete(key string) error
	Has(key string) (bool, error)
	Watch(keys []string) (<-chan struct{}, error)
}

type AppConfigLoader interface {
	Load(path string) (*AppConfig, error)
	Save(config *AppConfig, path string) error
	DefaultPath() (string, error)
}

type RemoteManager interface {
	Add(remote *EndpointConfig) error
	Remove(name string) error
	List() ([]*EndpointConfig, error)
	Get(name string) (*EndpointConfig, error)
	SetDefault(name string) error
	GetDefault() (*EndpointConfig, error)
}
