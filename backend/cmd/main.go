package main

import (
	"crypto/rand"
	"encoding/hex"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"golang.org/x/crypto/bcrypt"

	"github.com/dezhishen/self-hosted-server-traefik/backend/config"
	"github.com/dezhishen/self-hosted-server-traefik/backend/core"
	"github.com/dezhishen/self-hosted-server-traefik/backend/internal/server"
	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	configPath := flag.String("c", "", "config file path")
	flag.Parse()

	args := flag.Args()
	if len(args) > 0 && args[0] == "passwd" {
		os.Exit(passwdCmd(*configPath, args[1:]))
	}

	app, err := core.NewApp(*configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: failed to initialize app: %v\n", err)
		os.Exit(1)
	}
	defer app.Close()

	app.Logger.Info("endpoint contexts initialized", logger.Int("count", len(app.Endpoints)), logger.String("default", app.DefaultEndpoint))

	srv := server.New(app)

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		app.Logger.Info("shutting down")
		app.Close()
		os.Exit(0)
	}()

	if err := srv.Start(*addr); err != nil {
		app.Logger.Error("server error", logger.Error(err))
		os.Exit(1)
	}
}

func passwdCmd(configPath string, args []string) int {
	if configPath == "" {
		fmt.Fprintln(os.Stderr, "ERROR: -c <config dir> is required")
		return 1
	}

	password := ""
	if len(args) > 0 {
		password = strings.Join(args, " ")
	} else {
		buf := make([]byte, 16)
		if _, err := rand.Read(buf); err != nil {
			fmt.Fprintf(os.Stderr, "Error generating password: %v\n", err)
			return 1
		}
		password = hex.EncodeToString(buf)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error hashing password: %v\n", err)
		return 1
	}

	cfgMgr := core.NewConfigManager(config.NewLoader(), configPath)
	cfg, err := cfgMgr.LoadOrInit()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
		return 1
	}

	auth := &contracts.AuthConfig{
		Username:     "admin",
		PasswordHash: string(hash),
	}

	if err := cfgMgr.SaveSystem(cfg.BaseDataDir, auth); err != nil {
		fmt.Fprintf(os.Stderr, "Error saving password: %v\n", err)
		return 1
	}

	fmt.Println("Password updated successfully")
	return 0
}
