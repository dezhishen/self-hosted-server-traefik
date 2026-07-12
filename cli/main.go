package main

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"github.com/dezhishen/self-hosted-server-traefik/sdk"
	"golang.org/x/crypto/bcrypt"
	"gopkg.in/yaml.v3"
)

var (
	version    = "dev"
	commit     = "none"
	date       = "unknown"
	mainExited = false // set true in tests to prevent os.Exit
)

func main() {
	os.Exit(run())
}

func run() int {
	ctx := context.Background()

	configPath := ""
	host := ""
	args := os.Args[1:]

	for i := 0; i < len(args); i++ {
		switch {
		case args[i] == "-c" && i+1 < len(args):
			configPath = args[i+1]
			i++
		case strings.HasPrefix(args[i], "-c="):
			configPath = strings.TrimPrefix(args[i], "-c=")
		case args[i] == "--host" && i+1 < len(args):
			host = args[i+1]
			i++
		case strings.HasPrefix(args[i], "--host="):
			host = strings.TrimPrefix(args[i], "--host=")
		}
	}

	clean := make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		switch {
		case args[i] == "-c":
			i++
		case strings.HasPrefix(args[i], "-c="):
			continue
		case args[i] == "--host":
			i++
		case strings.HasPrefix(args[i], "--host="):
			continue
		default:
			clean = append(clean, args[i])
		}
	}
	args = clean

	if len(args) < 1 {
		help()
		return 0
	}

	switch args[0] {
	case "help":
		help()

	case "init":
		return initCmd(args[1:])

	case "version":
		fmt.Printf("selfhosted %s (commit: %s, built: %s)\n", version, commit, date)

	case "passwd":
		return passwdCmd(configPath, args[1:])

	case "install", "uninstall", "status", "list", "apprepo", "remote", "serve":
		client, err := sdk.New(ctx, sdk.Options{ConfigPath: configPath, Host: host})
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			return 1
		}
		defer client.Close()

		switch args[0] {
		case "install":
			if len(args) < 2 {
				fmt.Println("Usage: selfhosted install <service> [key=val ...]")
				return 2
			}
			params := make(map[string]string)
			for _, p := range args[2:] {
				parts := strings.SplitN(p, "=", 2)
				if len(parts) == 2 {
					params[parts[0]] = parts[1]
				}
			}
			if err := client.Install(ctx, args[1], params); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				return 1
			}

		case "uninstall":
			if len(args) < 2 {
				fmt.Println("Usage: selfhosted uninstall <service>")
				return 2
			}
			if err := client.Uninstall(ctx, args[1]); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				return 1
			}

		case "status":
			if len(args) < 2 {
				fmt.Println("Usage: selfhosted status <service>")
				return 2
			}
			status, err := client.Status(ctx, args[1])
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				return 1
			}
			fmt.Printf("Service: %s\nStatus:  %s\n", status.Name, status.Status)

		case "list":
			services, err := client.List(ctx)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				return 1
			}
			if len(services) == 0 {
				fmt.Println("No services installed")
				return 0
			}
			for _, s := range services {
				fmt.Printf("%-20s %s\n", s.Name, s.Category)
			}

		case "serve":
			addr := ":8080"
			backendAddr := ":18080"
			if len(args) > 1 {
				addr = args[1]
			}

			backendCmd := startBackend(backendAddr, configPath)
			if backendCmd != nil {
				defer func() {
					backendCmd.Process.Signal(os.Interrupt)
					backendCmd.Wait()
				}()
			}

			web, err := frontendFS()
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error loading frontend: %v\n", err)
				return 1
			}
			mux := http.NewServeMux()
			mux.Handle("/", http.FileServer(http.FS(web)))
			backendURL, _ := url.Parse(fmt.Sprintf("http://localhost%s", backendAddr))
			mux.Handle("/api/", httputil.NewSingleHostReverseProxy(backendURL))
			fmt.Printf("→ Dashboard available at http://localhost%s\n", addr)
			if err := http.ListenAndServe(addr, mux); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				return 1
			}

			case "apprepo":
				if len(args) < 2 {
					fmt.Println("Usage: selfhosted apprepo <add|remove|list|sync> ...")
					return 2
				}
				switch args[1] {
				case "add":
					if len(args) < 4 {
						fmt.Println("Usage: selfhosted apprepo add <name> <url>")
						return 2
					}
					if err := client.AppRepoAdd(ctx, args[2], args[3]); err != nil {
						fmt.Fprintf(os.Stderr, "Error: %v\n", err)
						return 1
					}
				case "remove":
					if len(args) < 3 {
						fmt.Println("Usage: selfhosted apprepo remove <name>")
						return 2
					}
					if err := client.AppRepoRemove(ctx, args[2]); err != nil {
						fmt.Fprintf(os.Stderr, "Error: %v\n", err)
						return 1
					}
				case "list":
					repos, err := client.AppRepoList(ctx)
					if err != nil {
						fmt.Fprintf(os.Stderr, "Error: %v\n", err)
						return 1
					}
					for _, s := range repos {
						fmt.Printf("%-20s %s\n", s.Name, s.URL)
					}
				case "sync":
					if len(args) < 3 {
						fmt.Println("Usage: selfhosted apprepo sync <name>")
						return 2
					}
					if err := client.AppRepoSync(ctx, args[2]); err != nil {
						fmt.Fprintf(os.Stderr, "Error: %v\n", err)
						return 1
					}
				default:
					fmt.Printf("unknown apprepo command: %s\n", args[1])
					return 2
				}

		case "remote":
			if len(args) < 2 {
				fmt.Println("Usage: selfhosted remote <add|remove|list> ...")
				return 2
			}
			switch args[1] {
			case "add":
				if len(args) < 4 {
					fmt.Println("Usage: selfhosted remote add <name> <addr>")
					return 2
				}
				if err := client.RemoteAdd(ctx, args[2], args[3]); err != nil {
					fmt.Fprintf(os.Stderr, "Error: %v\n", err)
					return 1
				}
			case "remove":
				if len(args) < 3 {
					fmt.Println("Usage: selfhosted remote remove <name>")
					return 2
				}
				if err := client.RemoteRemove(ctx, args[2]); err != nil {
					fmt.Fprintf(os.Stderr, "Error: %v\n", err)
					return 1
				}
			case "list":
				remotes, err := client.RemoteList(ctx)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Error: %v\n", err)
					return 1
				}
				for _, r := range remotes {
					fmt.Printf("%-20s\n", r.Name)
				}
			default:
				fmt.Printf("unknown remote command: %s\n", args[1])
				return 2
			}

		}

	default:
		fmt.Printf("unknown command: %s\n", args[0])
		help()
		return 2
	}
	return 0
}

func startBackend(addr, configPath string) *exec.Cmd {
	bin := findBackendBinary()
	if bin == "" {
		log.Println("Warning: backend binary not found, API will return stub responses")
		return nil
	}
	args := []string{"--addr", addr}
	if configPath != "" {
		args = append(args, "-c", configPath)
	}
	cmd := exec.Command(bin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		log.Printf("Warning: failed to start backend: %v", err)
		return nil
	}
	log.Printf("Backend started (PID %d) on %s", cmd.Process.Pid, addr)
	return cmd
}

func findBackendBinary() string {
	candidates := []string{
		"selfhosted-backend",
		filepath.Join("bin", "selfhosted-backend"),
	}
	if exe, err := os.Executable(); err == nil {
		dir := filepath.Dir(exe)
		candidates = append(candidates, filepath.Join(dir, "selfhosted-backend"))
	}
	for _, c := range candidates {
		if path, err := exec.LookPath(c); err == nil {
			return path
		}
	}
	return ""
}

func passwdCmd(configPath string, args []string) int {
	if configPath == "" {
		home, _ := os.UserHomeDir()
		configPath = filepath.Join(home, ".config", "selfhosted")
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

	// Determine if configPath is a directory (new format) or file (old format)
	sysPath := configPath
	info, err := os.Stat(configPath)
	if err == nil && info.IsDir() {
		sysPath = filepath.Join(configPath, "system.yaml")
	}

	data, err := os.ReadFile(sysPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading config %s: %v\n", sysPath, err)
		return 1
	}

	if sysPath != configPath {
		// New directory format: read system.yaml as SystemConfig
		var sys contracts.SystemConfig
		if err := yaml.Unmarshal(data, &sys); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing system.yaml: %v\n", err)
			return 1
		}
		username := "admin"
		if sys.Auth != nil && sys.Auth.Username != "" {
			username = sys.Auth.Username
		}
		sys.Auth = &contracts.AuthConfig{
			Username:     username,
			PasswordHash: string(hash),
		}
		out, err := yaml.Marshal(&sys)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error marshaling system.yaml: %v\n", err)
			return 1
		}
		if err := os.WriteFile(sysPath, out, 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing system.yaml: %v\n", err)
			return 1
		}
		fmt.Printf("Password updated.\n")
		fmt.Printf("  Username: %s\n", username)
		fmt.Printf("  Password: %s\n", password)
		fmt.Printf("  Config:   %s\n", sysPath)
	} else {
		// Old single-file format
		var cfg contracts.AppConfig
		if err := yaml.Unmarshal(data, &cfg); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing config: %v\n", err)
			return 1
		}
		username := "admin"
		if cfg.Auth != nil && cfg.Auth.Username != "" {
			username = cfg.Auth.Username
		}
		cfg.Auth = &contracts.AuthConfig{
			Username:     username,
			PasswordHash: string(hash),
		}
		out, err := yaml.Marshal(&cfg)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error marshaling config: %v\n", err)
			return 1
		}
		if err := os.WriteFile(configPath, out, 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing config: %v\n", err)
			return 1
		}
		fmt.Printf("Password updated.\n")
		fmt.Printf("  Username: %s\n", username)
		fmt.Printf("  Password: %s\n", password)
		fmt.Printf("  Config:   %s\n", configPath)
	}
	return 0
}

func initCmd(args []string) int {
	scanner := bufio.NewScanner(os.Stdin)

	// 1. Server address
	fmt.Print("Server address (e.g. http://192.168.1.100:18080): ")
	if !scanner.Scan() {
		fmt.Fprintln(os.Stderr, "Input cancelled")
		return 1
	}
	server := strings.TrimSpace(scanner.Text())
	if server == "" {
		fmt.Fprintln(os.Stderr, "Server address is required")
		return 1
	}
	if !strings.HasPrefix(server, "http://") && !strings.HasPrefix(server, "https://") {
		server = "http://" + server
	}

	// 2. Auth method
	fmt.Println()
	fmt.Println("Authentication:")
	fmt.Println("  1) Username/Password (will create an API key)")
	fmt.Println("  2) Existing API key")
	fmt.Print("Choose (1/2): ")
	if !scanner.Scan() {
		fmt.Fprintln(os.Stderr, "Input cancelled")
		return 1
	}
	authMethod := strings.TrimSpace(scanner.Text())

	ctx := context.Background()
	var apiKey string

	switch authMethod {
	case "1":
		fmt.Print("Username (default: admin): ")
		if !scanner.Scan() {
			fmt.Fprintln(os.Stderr, "Input cancelled")
			return 1
		}
		username := strings.TrimSpace(scanner.Text())
		if username == "" {
			username = "admin"
		}

		fmt.Print("Password: ")
		if !scanner.Scan() {
			fmt.Fprintln(os.Stderr, "Input cancelled")
			return 1
		}
		password := strings.TrimSpace(scanner.Text())
		if password == "" {
			fmt.Fprintln(os.Stderr, "Password is required")
			return 1
		}

		// Create unauthenticated client for login
		client, err := sdk.New(ctx, sdk.Options{Server: server})
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error creating client: %v\n", err)
			return 1
		}
		defer client.Close()

		fmt.Println("→ Logging in...")
		sessionToken, err := client.Login(ctx, username, password)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Login failed: %v\n", err)
			fmt.Println("  (Check server address and credentials)")
			return 1
		}

		fmt.Println("→ Creating API key...")
		apiKey, err = client.CreateAPIKey(ctx, sessionToken, "cli", "CLI auto-generated key")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to create API key: %v\n", err)
			return 1
		}

	case "2":
		fmt.Print("API key: ")
		if !scanner.Scan() {
			fmt.Fprintln(os.Stderr, "Input cancelled")
			return 1
		}
		apiKey = strings.TrimSpace(scanner.Text())
		if apiKey == "" {
			fmt.Fprintln(os.Stderr, "API key is required")
			return 1
		}

	default:
		fmt.Fprintf(os.Stderr, "Invalid choice: %s\n", authMethod)
		return 1
	}

	// 3. Save config
	client, err := sdk.New(ctx, sdk.Options{Server: server, APIKey: apiKey})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		return 1
	}
	defer client.Close()

	configPath := filepath.Join(os.Getenv("HOME"), ".config", "selfhosted", "client.yaml")
	if err := client.SaveConfig(configPath); err != nil {
		fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
		return 1
	}

	fmt.Println()
	fmt.Println("✓ Initialization complete!")
	fmt.Printf("  Server:  %s\n", server)
	fmt.Printf("  Config:  %s\n", configPath)
	return 0
}

func help() {
	fmt.Println(`selfhosted - Self-hosted server deployment tool

Usage:
  selfhosted [flags] <command> [args]

Flags:
  -c, --config <dir>      Config directory path (contains system.yaml + endpoints.yaml)
  --host <connection>     Remote runtime connection

Commands:
  init                    Interactive initialization (server, auth, API key)
  install <service>       Install a service
  uninstall <service>     Uninstall a service
  status <service>        Service status
  list                    List services
  serve [addr]            Start web dashboard
  passwd [password]       Reset password (random if omitted)
  apprepo add/remove/list/sync  Manage app repositories
  remote add/remove/list  Manage remote hosts
  version                 Show version
  help                    Show this help`)
}
