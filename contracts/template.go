package contracts

type TemplateEngine interface {
	RenderString(template string, data *TemplateData) (string, error)
	RenderFile(path string, data *TemplateData) (string, error)
	RenderFS(files map[string]string, data *TemplateData) (map[string]string, error)
}

type TemplateData struct {
	Service     *ServiceDefinition    `yaml:"service,omitempty" json:"service,omitempty"`
	Params      []*ParamValue         `yaml:"params,omitempty" json:"params,omitempty"`
	ParamMap    map[string]interface{} `yaml:"-" json:"-"`
	Endpoint    *EndpointConfig       `yaml:"endpoint,omitempty" json:"endpoint,omitempty"`
	Custom      map[string]string     `yaml:"custom,omitempty" json:"custom,omitempty"`
	Environment map[string]string     `yaml:"environment,omitempty" json:"environment,omitempty"`
	Runtime     *RuntimeInfo          `yaml:"runtime,omitempty" json:"runtime,omitempty"`
	Extra       map[string]interface{} `yaml:"extra,omitempty" json:"extra,omitempty"`
}

// BuildParamMap creates a lookup map from the Params slice for template access.
func (d *TemplateData) BuildParamMap() {
	if len(d.Params) == 0 {
		return
	}
	d.ParamMap = make(map[string]interface{}, len(d.Params))
	for _, p := range d.Params {
		d.ParamMap[p.Name] = p.Value
	}
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
