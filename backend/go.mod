module github.com/dezhishen/self-hosted-server-traefik/backend

go 1.22

require (
	github.com/dezhishen/self-hosted-server-traefik/contracts v0.0.0
	go.uber.org/multierr v1.10.0 // indirect
	go.uber.org/zap v1.27.0
	gopkg.in/natefinch/lumberjack.v2 v2.2.1
	gopkg.in/yaml.v3 v3.0.1
)

replace github.com/dezhishen/self-hosted-server-traefik/contracts => ../contracts
