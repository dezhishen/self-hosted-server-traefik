module github.com/dezhishen/self-hosted-server-traefik/cli

go 1.22

require (
	github.com/dezhishen/self-hosted-server-traefik/contracts v0.0.0
	github.com/dezhishen/self-hosted-server-traefik/sdk v0.0.0
	golang.org/x/crypto v0.31.0
	gopkg.in/yaml.v3 v3.0.1
)

replace (
	github.com/dezhishen/self-hosted-server-traefik/contracts => ../contracts
	github.com/dezhishen/self-hosted-server-traefik/sdk => ../sdk
)


