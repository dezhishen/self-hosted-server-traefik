package contracts

type MigrateService interface {
	Analyze(epName string) ([]*MigrationCandidate, error)
	Generate(req *GenerateAppRequest) (*GenerateAppResult, error)
	Adopt(req *AdoptRequest) (*AdoptResult, error)
	PreviewAdopt(req *AdoptPreviewRequest) (*AdoptPreviewResult, error)
}

type MigrationCandidate struct {
	Container       *ContainerInfo `json:"container"`
	MatchedService  string         `json:"matched_service"`
	Services        []string       `json:"services"`
	ExtractedParams []*ParamValue  `json:"extracted_params"`
}

type GenerateAppRequest struct {
	ContainerID string `json:"container_id"`
	ServiceName string `json:"service_name"`
}

type GenerateAppResult struct {
	ServiceName string `json:"service_name"`
	FilePath    string `json:"file_path"`
}

// AdoptRequest is used to rebuild an existing container as a managed service.
// The original container is stopped and removed, then recreated with the same
// configuration plus managed labels. If ServiceName matches a known service
// template and Params are provided, the template install pipeline is used.
type AdoptRequest struct {
	ContainerID string        `json:"container_id"`
	ServiceName string        `json:"service_name"`
	RepoName    string        `json:"repo_name,omitempty"`
	Version     string        `json:"version,omitempty"`
	Params      []*ParamValue `json:"params,omitempty"`
}

type AdoptResult struct {
	ContainerID string            `json:"container_id"`
	ServiceName string            `json:"service_name"`
	RepoName    string            `json:"repo_name,omitempty"`
	Endpoint    string            `json:"endpoint"`
	Labels      map[string]string `json:"labels"`
}

// AdoptPreviewRequest is used to preview what an adoption would create.
type AdoptPreviewRequest struct {
	ContainerID string        `json:"container_id"`
	ServiceName string        `json:"service_name"`
	Params      []*ParamValue `json:"params,omitempty"`
}

// AdoptPreviewResult contains the preview of what would be created by Adopt.
type AdoptPreviewResult struct {
	RunParams      *ContainerRunParams `json:"run_params"`
	DockerRunCmd   string              `json:"docker_run_cmd"`
	ServiceName    string              `json:"service_name"`
	OriginalLabels map[string]string   `json:"original_labels"`
}
