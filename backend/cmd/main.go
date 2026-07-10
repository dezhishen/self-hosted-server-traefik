package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/dezhishen/self-hosted-server-traefik/backend/core"
	"github.com/dezhishen/self-hosted-server-traefik/backend/internal/server"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	configPath := flag.String("c", "", "config file path")
	flag.Parse()

	app, err := core.NewApp(*configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: failed to initialize app: %v\n", err)
		os.Exit(1)
	}
	defer app.Close()

	app.Logger.Sugar().Infof("endpoint contexts initialized: count=%d, default=%s", len(app.Endpoints), app.DefaultEndpoint)

	srv := server.New(app)

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		app.Logger.Sugar().Info("shutting down")
		app.Close()
		os.Exit(0)
	}()

	if err := srv.Start(*addr); err != nil {
		app.Logger.Sugar().Errorf("server error: %v", err)
		os.Exit(1)
	}
}
