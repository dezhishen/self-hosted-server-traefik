package core

import "github.com/dezhishen/self-hosted-server-traefik/backend/logger"

func InitLogger(baseDir string) logger.Logger {
	return logger.InitLogger(baseDir)
}
