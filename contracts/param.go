package contracts

type ParamType string

const (
	ParamTypeString   ParamType = "string"
	ParamTypePassword ParamType = "password"
	ParamTypeArray    ParamType = "array"
	ParamTypeBool     ParamType = "bool"
	ParamTypeNumber   ParamType = "number"
	ParamTypeSelect   ParamType = "select"
)

type ParamDef struct {
	Name        string            `yaml:"name" json:"name"`
	Type        ParamType         `yaml:"type" json:"type"`
	Label       string            `yaml:"label,omitempty" json:"label,omitempty"`
	Description string            `yaml:"description,omitempty" json:"description,omitempty"`
	Required    bool              `yaml:"required,omitempty" json:"required,omitempty"`
	Default     interface{}       `yaml:"default,omitempty" json:"default,omitempty"`
	Options     []string          `yaml:"options,omitempty" json:"options,omitempty"`
	MinLength   int               `yaml:"min_length,omitempty" json:"min_length,omitempty"`
	MaxLength   int               `yaml:"max_length,omitempty" json:"max_length,omitempty"`
	Pattern     string            `yaml:"pattern,omitempty" json:"pattern,omitempty"`
	DependsOn   []string          `yaml:"depends_on,omitempty" json:"depends_on,omitempty"`
	Group       string            `yaml:"group,omitempty" json:"group,omitempty"`
	Order       int               `yaml:"order,omitempty" json:"order,omitempty"`
	Secret      bool              `yaml:"secret,omitempty" json:"secret,omitempty"`
	EnvMapping  map[string]string `yaml:"env_mapping,omitempty" json:"env_mapping,omitempty"`
	Validate    string            `yaml:"validate,omitempty" json:"validate,omitempty"`
}

type ParamValue struct {
	Name  string      `yaml:"name" json:"name"`
	Value interface{} `yaml:"value" json:"value"`
}

type RenderMode string

const (
	RenderPlain  RenderMode = "plain"
	RenderMasked RenderMode = "masked"
	RenderJSON   RenderMode = "json"
	RenderEnv    RenderMode = "env"
	RenderVolume RenderMode = "volume"
)

type ParamStore interface {
	Get(name string) (*ParamValue, error)
	Set(value *ParamValue) error
	GetAll() ([]*ParamValue, error)
	Delete(name string) error
	Has(name string) (bool, error)
	ListDefs() ([]*ParamDef, error)
	Watch(names []string) (<-chan struct{}, error)
}

type ParamRenderer interface {
	Render(params []*ParamValue, defs []*ParamDef, mode RenderMode) (map[string]string, error)
	RenderEnv(params []*ParamValue, defs []*ParamDef) (map[string]string, error)
	RenderVolume(params []*ParamValue, defs []*ParamDef) (map[string]string, error)
	RenderDisplay(params []*ParamValue, defs []*ParamDef) (map[string]string, error)
}

type ParamValidator interface {
	Validate(value *ParamValue, def *ParamDef) error
}

type PasswordEncryptor interface {
	Encrypt(plaintext string) (string, error)
	Decrypt(ciphertext string) (string, error)
}
