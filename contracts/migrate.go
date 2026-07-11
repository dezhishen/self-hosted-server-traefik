package contracts

type MigrateService interface {
	Analyze(epName string) ([]*MigrationCandidate, error)
	Execute(req *MigrationRequest) (string, error)
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
