package contracts

const (
	labelPrefix          = "selfhosted."
	ManagedLabelKey      = labelPrefix + "managed"
	ManagedLabelValue    = "true"
	ManagedServiceLabel  = labelPrefix + "service"
	ManagedVersionLabel  = labelPrefix + "version"
	ManagedHostLabel     = labelPrefix + "host"
	ManagedEngineLabel   = labelPrefix + "engine"
)

func ManagedLabels(service, version, host, engine string) map[string]string {
	return map[string]string{
		ManagedLabelKey:     ManagedLabelValue,
		ManagedServiceLabel: service,
		ManagedVersionLabel: version,
		ManagedHostLabel:    host,
		ManagedEngineLabel:  engine,
	}
}
