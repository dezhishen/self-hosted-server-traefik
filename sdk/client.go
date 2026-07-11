package sdk

import (
	"context"
	"fmt"
	"io"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time checks:
var _ io.Closer = (*Client)(nil) // Close() error

type Client struct {
	Runtime   contracts.ContainerRuntime
	Config    contracts.ConfigStore
	Params    contracts.ParamStore
	Services  contracts.ServiceManager
	Subs      contracts.SubscriptionManager
	Remotes   contracts.RemoteManager
	Loader    contracts.ServiceLoader
	Validator contracts.ServiceValidator
	Template  contracts.TemplateEngine
}

type Options struct {
	ConfigPath string
	Host       string
}

func New(ctx context.Context, opts Options) (*Client, error) {
	return &Client{}, nil
}

func (c *Client) Close() error { return nil }

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
