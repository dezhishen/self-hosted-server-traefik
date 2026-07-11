package docker

import (
	"context"
	"fmt"
	"net"
	"strconv"
	"strings"

	gossh "golang.org/x/crypto/ssh"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// sshDialer provides a DialContext function that tunnels connections
// through an SSH connection to a remote Docker Unix socket.
type sshDialer struct {
	client     *gossh.Client
	socketPath string
}

// DialContext implements the Docker SDK dialer interface.
// It ignores network and addr, always dialing the remote Unix socket
// through the established SSH connection.
func (d *sshDialer) DialContext(ctx context.Context, network, addr string) (net.Conn, error) {
	return d.client.Dial("unix", d.socketPath)
}

// Close closes the underlying SSH connection.
func (d *sshDialer) Close() error {
	return d.client.Close()
}

// newSSHDialer creates an SSH tunnel dialer from a connection config.
// It parses the private key, establishes an SSH connection to the remote host,
// and returns a dialer that tunnels Docker API calls through the SSH connection.
func newSSHDialer(cfg *contracts.ConnectionConfig) (*sshDialer, error) {
	if cfg.SSHPrivateKey == "" {
		return nil, fmt.Errorf("SSH private key is required for ssh connection type")
	}

	// Parse private key
	signer, err := gossh.ParsePrivateKey([]byte(cfg.SSHPrivateKey))
	if err != nil {
		return nil, fmt.Errorf("parse SSH private key: %w", err)
	}

	// Build SSH config
	sshUser := cfg.SSHUser
	if sshUser == "" {
		sshUser = "root"
	}

	sshConfig := &gossh.ClientConfig{
		User:            sshUser,
		Auth:            []gossh.AuthMethod{gossh.PublicKeys(signer)},
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
	}

	// Parse host:port from endpoint
	host := cfg.Endpoint
	port := 22
	if parts := strings.Split(host, ":"); len(parts) == 2 {
		host = parts[0]
		if p, err := strconv.Atoi(parts[1]); err == nil {
			port = p
		}
	}

	addr := net.JoinHostPort(host, strconv.Itoa(port))

	// Establish SSH connection
	sshClient, err := gossh.Dial("tcp", addr, sshConfig)
	if err != nil {
		return nil, fmt.Errorf("SSH dial %s: %w", addr, err)
	}

	// Determine remote socket path
	socketPath := "/var/run/docker.sock"
	if cfg.Endpoint != "" {
		// For SSH type, endpoint is the host. But some configs might
		// specify a custom socket path. Use endpoint as host, not socket path.
		// The socket path is always /var/run/docker.sock on the remote host.
		_ = socketPath // keep default
	}

	return &sshDialer{
		client:     sshClient,
		socketPath: socketPath,
	}, nil
}
