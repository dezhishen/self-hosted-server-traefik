module github.com/dezhishen/self-hosted-server-traefik/backend

go 1.25.0

require (
	github.com/dezhishen/self-hosted-server-traefik/contracts v0.0.0
	github.com/docker/go-connections v0.7.0
	github.com/moby/moby/api v1.55.0
	github.com/moby/moby/client v0.5.0
	go.uber.org/zap v1.27.0
	golang.org/x/crypto v0.0.0-20220622213112-05595931fe9d
	gopkg.in/natefinch/lumberjack.v2 v2.2.1
	gopkg.in/yaml.v3 v3.0.1
)

require (
	github.com/Microsoft/go-winio v0.6.2 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/containerd/errdefs v1.0.0 // indirect
	github.com/containerd/errdefs/pkg v0.3.0 // indirect
	github.com/distribution/reference v0.6.0 // indirect
	github.com/docker/go-units v0.5.0 // indirect
	github.com/felixge/httpsnoop v1.0.4 // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/moby/docker-image-spec v1.3.1 // indirect
	github.com/opencontainers/go-digest v1.0.0 // indirect
	github.com/opencontainers/image-spec v1.1.1 // indirect
	go.opentelemetry.io/auto/sdk v1.2.1 // indirect
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.69.0 // indirect
	go.opentelemetry.io/otel v1.44.0 // indirect
	go.opentelemetry.io/otel/metric v1.44.0 // indirect
	go.opentelemetry.io/otel/trace v1.44.0 // indirect
	go.uber.org/multierr v1.10.0 // indirect
	golang.org/x/sys v0.45.0 // indirect
)

replace github.com/dezhishen/self-hosted-server-traefik/contracts => ../contracts
