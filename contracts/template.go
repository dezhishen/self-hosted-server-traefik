package contracts

type TemplateEngine interface {
	RenderString(template string, data *TemplateData) (string, error)
	RenderFile(path string, data *TemplateData) (string, error)
	RenderFS(files map[string]string, data *TemplateData) (map[string]string, error)
}

type TemplateData struct {
	Service     *ServiceDefinition `yaml:"service,omitempty" json:"service,omitempty"`
	Params      []*ParamValue      `yaml:"params,omitempty" json:"params,omitempty"`
	Endpoint    *EndpointConfig    `yaml:"endpoint,omitempty" json:"endpoint,omitempty"`
	Environment map[string]string  `yaml:"environment,omitempty" json:"environment,omitempty"`
	Runtime     *RuntimeInfo       `yaml:"runtime,omitempty" json:"runtime,omitempty"`
	Extra       map[string]interface{} `yaml:"extra,omitempty" json:"extra,omitempty"`
}

type ServiceLoader interface {
	LoadAll() ([]*ServiceDefinition, error)
	Load(name string) (*ServiceDefinition, error)
	Discover(paths []string) ([]*ServiceDefinition, error)
}

type ServiceValidator interface {
	Validate(service *ServiceDefinition) error
	ValidateAll(services []*ServiceDefinition) error
}
