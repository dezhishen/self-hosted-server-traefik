package sdk

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"gopkg.in/yaml.v3"
)

// ClientConfig represents the SDK client configuration file.
type ClientConfig struct {
	Server string `yaml:"server" json:"server"`
	APIKey string `yaml:"api_key" json:"api_key"`
}

// defaultConfigPath returns the default SDK config file path.
func defaultConfigPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "selfhosted", "client.yaml")
}

// Client is an HTTP client for the self-hosted server API.
type Client struct {
	server    string
	apiKey    string
	apiClient *http.Client
}

// Options for creating a new SDK client.
type Options struct {
	ConfigPath string
	Host       string
	Server     string
	APIKey     string
}

// New creates a new SDK Client.
//
// Config resolution order:
//  1. opts.Server + opts.APIKey (highest priority)
//  2. opts.ConfigPath (load from YAML file)
//  3. opts.Host (legacy runtime connection string)
//  4. default config path (~/.config/selfhosted/client.yaml)
func New(ctx context.Context, opts Options) (*Client, error) {
	server := opts.Server
	apiKey := opts.APIKey

	// Load from config file if server not already set
	if server == "" && opts.ConfigPath != "" {
		cfg, err := loadConfigFile(opts.ConfigPath)
		if err == nil {
			server = cfg.Server
			apiKey = cfg.APIKey
		}
	}

	// Fallback to default config path
	if server == "" {
		cfg, err := loadConfigFile(defaultConfigPath())
		if err == nil {
			server = cfg.Server
			apiKey = cfg.APIKey
		}
	}

	// Legacy Host option (for backward compatibility)
	if server == "" && opts.Host != "" {
		server = opts.Host
	}

	if server == "" {
		return nil, fmt.Errorf("no server configured: specify --host, set server in config, or run 'selfhosted init'")
	}

	// Normalize server URL: add scheme if missing
	if !strings.HasPrefix(server, "http://") && !strings.HasPrefix(server, "https://") {
		server = "http://" + server
	}
	server = strings.TrimRight(server, "/")

	return &Client{
		server:    server,
		apiKey:    apiKey,
		apiClient: &http.Client{},
	}, nil
}

// Close cleans up the client.
func (c *Client) Close() error {
	if c != nil && c.apiClient != nil {
		c.apiClient.CloseIdleConnections()
	}
	return nil
}

// ============================================================
// Internal helpers
// ============================================================

func loadConfigFile(path string) (*ClientConfig, error) {
	if path == "" {
		return nil, fmt.Errorf("no config path")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg ClientConfig
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	if cfg.Server == "" {
		return nil, fmt.Errorf("missing server in config")
	}
	return &cfg, nil
}

// SaveConfig writes the client config to the given path (or default).
func (c *Client) SaveConfig(path string) error {
	if path == "" {
		path = defaultConfigPath()
	}
	cfg := ClientConfig{
		Server: c.server,
		APIKey: c.apiKey,
	}
	data, err := yaml.Marshal(&cfg)
	if err != nil {
		return fmt.Errorf("marshal config: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("write config: %w", err)
	}
	return nil
}

// doRequest sends an authenticated HTTP request.
func (c *Client) doRequest(ctx context.Context, method, path string, body interface{}) (*http.Response, error) {
	var reqBody io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("marshal request: %w", err)
		}
		reqBody = bytes.NewReader(data)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.server+path, reqBody)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.apiClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	return resp, nil
}

// doJSON sends a request and decodes the JSON response.
func (c *Client) doJSON(ctx context.Context, method, path string, body, result interface{}) error {
	resp, err := c.doRequest(ctx, method, path, body)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		errBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("API error (%d): %s", resp.StatusCode, string(errBody))
	}

	if result != nil {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("decode response: %w", err)
		}
	}
	return nil
}

// ============================================================
// Auth
// ============================================================

// Login authenticates with username/password and returns a session token.
// The SDK does NOT use session tokens for subsequent requests; it uses API keys.
// This method is used internally by the CLI init command to create an API key.
func (c *Client) Login(ctx context.Context, username, password string) (string, error) {
	var result struct {
		Token string `json:"token"`
	}
	if err := c.doJSON(ctx, http.MethodPost, "/api/auth/login", map[string]string{
		"username": username,
		"password": password,
	}, &result); err != nil {
		return "", err
	}
	return result.Token, nil
}

// CreateAPIKey creates a new API key. Requires a session token (from Login).
func (c *Client) CreateAPIKey(ctx context.Context, sessionToken, scope, description string) (string, error) {
	var result struct {
		Key string `json:"key"`
	}

	// Temporarily override the API key for this request
	oldKey := c.apiKey
	c.apiKey = sessionToken
	defer func() { c.apiKey = oldKey }()

	if err := c.doJSON(ctx, http.MethodPost, "/api/apikeys", map[string]string{
		"scope":       scope,
		"description": description,
	}, &result); err != nil {
		return "", err
	}
	return result.Key, nil
}

// ============================================================
// Stub methods — not yet implemented via remote API
// ============================================================

func (c *Client) Install(ctx context.Context, name string, params map[string]string) error {
	return fmt.Errorf("not implemented")
}

func (c *Client) Uninstall(ctx context.Context, name string) error {
	return fmt.Errorf("not implemented")
}

func (c *Client) Status(ctx context.Context, name string) (*contracts.ServiceStatusResult, error) {
	return nil, fmt.Errorf("not implemented")
}

func (c *Client) List(ctx context.Context) ([]contracts.ServiceDefinition, error) {
	return nil, fmt.Errorf("not implemented")
}

func (c *Client) ListByCategory(ctx context.Context, category string) ([]contracts.ServiceDefinition, error) {
	return nil, fmt.Errorf("not implemented")
}

func (c *Client) ConfigGet(ctx context.Context, key string) (string, error) {
	return "", fmt.Errorf("not implemented")
}

func (c *Client) ConfigSet(ctx context.Context, key, value string) error {
	return fmt.Errorf("not implemented")
}

func (c *Client) ParamGet(ctx context.Context, key string) (string, error) {
	return "", fmt.Errorf("not implemented")
}

func (c *Client) SubAdd(ctx context.Context, name, url string) error {
	return fmt.Errorf("not implemented")
}

func (c *Client) SubRemove(ctx context.Context, name string) error {
	return fmt.Errorf("not implemented")
}

func (c *Client) SubList(ctx context.Context) ([]contracts.Subscription, error) {
	return nil, fmt.Errorf("not implemented")
}

func (c *Client) SubSync(ctx context.Context, name string) error {
	return fmt.Errorf("not implemented")
}

func (c *Client) RemoteAdd(ctx context.Context, name, addr string) error {
	return fmt.Errorf("not implemented")
}

func (c *Client) RemoteRemove(ctx context.Context, name string) error {
	return fmt.Errorf("not implemented")
}

func (c *Client) RemoteList(ctx context.Context) ([]*contracts.EndpointConfig, error) {
	return nil, fmt.Errorf("not implemented")
}

func (c *Client) Serve(ctx context.Context, addr string) error {
	return fmt.Errorf("not implemented")
}
