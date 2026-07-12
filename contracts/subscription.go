package contracts

type AppRepo struct {
	Name        string `yaml:"name" json:"name"`
	URL         string `yaml:"url" json:"url"`
	Description string `yaml:"description,omitempty" json:"description,omitempty"`
	Branch      string `yaml:"branch,omitempty" json:"branch,omitempty"`
	Enabled     bool   `yaml:"enabled" json:"enabled"`
	AutoUpdate  bool   `yaml:"auto_update,omitempty" json:"auto_update,omitempty"`
}

type AppRepoManager interface {
	Add(sub *AppRepo) error
	Remove(name string) error
	List() ([]*AppRepo, error)
	Get(name string) (*AppRepo, error)
	Sync(name string) error
	SyncAll() error
	GetLocalPath(name string) (string, error)
}

type AppRepoOptions struct {
	CloneTimeout  int  `yaml:"clone_timeout,omitempty" json:"clone_timeout,omitempty"`
	FetchTimeout  int  `yaml:"fetch_timeout,omitempty" json:"fetch_timeout,omitempty"`
	ShallowClone  bool `yaml:"shallow_clone,omitempty" json:"shallow_clone,omitempty"`
	CleanOnRemove bool `yaml:"clean_on_remove,omitempty" json:"clean_on_remove,omitempty"`
}

type AppRepoStore interface {
	Load() ([]*AppRepo, error)
	Save(subscriptions []*AppRepo) error
}
