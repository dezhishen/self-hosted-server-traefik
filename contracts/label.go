package contracts

const (
	labelPrefix          = "selfhosted."
	ManagedLabelKey      = labelPrefix + "managed"
	ManagedLabelValue    = "true"
	ManagedServiceLabel  = labelPrefix + "service"
	ManagedRepoLabel     = labelPrefix + "repo"
	ManagedVersionLabel  = labelPrefix + "version"
	ManagedHostLabel     = labelPrefix + "host"
	ManagedEngineLabel   = labelPrefix + "engine"
)

func ManagedLabels(service, repo, version, host, engine string) map[string]string {
	return map[string]string{
		ManagedLabelKey:     ManagedLabelValue,
		ManagedServiceLabel: service,
		ManagedRepoLabel:    repo,
		ManagedVersionLabel: version,
		ManagedHostLabel:    host,
		ManagedEngineLabel:  engine,
	}
}
