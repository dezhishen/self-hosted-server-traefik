package contracts

type MigrateService interface {
	Analyze(epName string) ([]*MigrationCandidate, error)
	Execute(req *MigrationRequest) (string, error)
	Generate(req *GenerateTemplateRequest) (*GenerateTemplateResult, error)
	Adopt(req *AdoptRequest) (*AdoptResult, error)
}

type MigrationCandidate struct {
	Container       *ContainerInfo `json:"container"`
	MatchedService  string         `json:"matched_service"`
	Services        []string       `json:"services"`
	ExtractedParams []*ParamValue  `json:"extracted_params"`
}

type MigrationRequest struct {
	ContainerID string        `json:"container_id"`
	ServiceName string        `json:"service_name"`
	Params      []*ParamValue `json:"params"`
	RemoveOld   bool          `json:"remove_old"`
}

type GenerateTemplateRequest struct {
	ContainerID string `json:"container_id"`
	ServiceName string `json:"service_name"`
}

type GenerateTemplateResult struct {
	ServiceName string `json:"service_name"`
	FilePath    string `json:"file_path"`
}

// AdoptRequest is used to adopt an existing running container as a managed service.
// The container keeps running — managed labels are added without recreating it.
type AdoptRequest struct {
	ContainerID string `json:"container_id"`
	ServiceName string `json:"service_name"`
	Version     string `json:"version,omitempty"`
}

// AdoptResult describes the result of a successful adoption.
type AdoptResult struct {
	ContainerID string            `json:"container_id"`
	ServiceName string            `json:"service_name"`
	Endpoint    string            `json:"endpoint"`
	Labels      map[string]string `json:"labels"`
}
