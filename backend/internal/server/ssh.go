package server

import (
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"

	gossh "golang.org/x/crypto/ssh"

	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// --- Request / Response types ---

type keygenRequest struct {
	Name         string `json:"name"`                    // key name (required)
	Type         string `json:"type"`                    // ed25519 (default), rsa-2048, etc.
	EndpointName string `json:"endpoint_name,omitempty"` // optional: assign key to endpoint
	Comment      string `json:"comment,omitempty"`       // optional description
}

type keygenResponse struct {
	KeyName     string `json:"key_name"`
	PublicKey   string `json:"public_key"`
	Fingerprint string `json:"fingerprint"`
	Type        string `json:"type"`
}

type sshImportRequest struct {
	Name         string `json:"name"`                    // key name (required)
	PrivateKey   string `json:"private_key"`             // PEM-encoded private key (required)
	EndpointName string `json:"endpoint_name,omitempty"` // optional: assign key to endpoint
}

type sshKeyInfo struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Fingerprint string `json:"fingerprint"`
	PublicKey   string `json:"public_key"`
}

type authorizeRequest struct {
	EndpointName    string `json:"endpoint_name"`
	KeyRef          string `json:"key_ref,omitempty"`          // optional: key ref to authorize; defaults to endpoint's ssh_key_ref
	TransportKeyRef string `json:"transport_key_ref,omitempty"` // optional: key to use for SSH transport auth
	Password        string `json:"password,omitempty"`
}

// --- POST /api/ssh/keygen ---

func (s *Server) handleSSHKeygen(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}

	var req keygenRequest
	if err := decodeJSON(r, &req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body").
			WithDetail("parse_error", err.Error())
	}
	if req.Name == "" {
		return ValidationError(ErrMissingField, "key name is required").
			WithDetail("field", "name")
	}
	if req.Type == "" {
		req.Type = "ed25519"
	}

	privKey, pubKey, err := generateSSHKeyPair(req.Type)
	if err != nil {
		return ValidationError(ErrInvalidValue, err.Error()).
			WithDetail("field", "type").
			WithDetail("value", req.Type)
	}

	privBytes, err := x509.MarshalPKCS8PrivateKey(privKey)
	if err != nil {
		return InternalError(ErrInternal, "failed to marshal private key").
			WithCause(err)
	}
	privPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: privBytes,
	})

	pubSSH := string(gossh.MarshalAuthorizedKey(pubKey))
	fingerprint := gossh.FingerprintSHA256(pubKey)
	keyType := req.Type

	entry := contracts.NewSSHKeyEntry(
		req.Name,
		string(privPEM),
		pubSSH,
		fingerprint,
		keyType,
		req.Comment,
	)

	if err := s.app.SSHKeyManager.Set(entry); err != nil {
		return InternalError(ErrConfigSave, "failed to save SSH key").
			WithCause(err)
	}

	// Optionally assign to endpoint
	if req.EndpointName != "" {
		if epCfg, ok := s.app.Config.Endpoints[req.EndpointName]; ok {
			if epCfg.Connection == nil {
				epCfg.Connection = &contracts.ConnectionConfig{}
			}
			epCfg.Connection.SSHKeyRef = req.Name
			if err := s.app.ConfigMgr.SaveEndpoints(s.app.Config.Endpoints); err != nil {
				return InternalError(ErrConfigSave, "failed to save endpoint config").
					WithCause(err)
			}
		} else {
			// Key was created but endpoint not found — still a success for keygen
			s.app.Logger.Warn("key generated but endpoint not found for assignment",
				logger.String("key", req.Name),
				logger.String("endpoint", req.EndpointName),
			)
		}
	}

	s.app.Logger.Info("ssh key pair generated and stored in key store",
		logger.String("key", req.Name),
		logger.String("type", keyType),
		logger.String("fingerprint", fingerprint),
	)

	jsonResp(w, keygenResponse{
		KeyName:     req.Name,
		PublicKey:   pubSSH,
		Fingerprint: fingerprint,
		Type:        keyType,
	})
	return nil
}

// --- POST /api/ssh/import ---

func (s *Server) handleSSHImport(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}

	var req sshImportRequest
	if err := decodeJSON(r, &req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body").
			WithDetail("parse_error", err.Error())
	}
	if req.Name == "" {
		return ValidationError(ErrMissingField, "key name is required").
			WithDetail("field", "name")
	}
	if req.PrivateKey == "" {
		return ValidationError(ErrMissingField, "private_key is required").
			WithDetail("field", "private_key")
	}

	pubKey, err := sshExtractPublicKey(req.PrivateKey)
	if err != nil {
		return ValidationError(ErrInvalidValue, "invalid private key").
			WithCause(err)
	}

	pubSSH := string(gossh.MarshalAuthorizedKey(pubKey))
	fingerprint := gossh.FingerprintSHA256(pubKey)
	keyType := sshKeyTypeName(pubKey.Type())

	entry := contracts.NewSSHKeyEntry(
		req.Name,
		req.PrivateKey,
		pubSSH,
		fingerprint,
		keyType,
		"",
	)

	if err := s.app.SSHKeyManager.Set(entry); err != nil {
		return InternalError(ErrConfigSave, "failed to save SSH key").
			WithCause(err)
	}

	// Optionally assign to endpoint
	if req.EndpointName != "" {
		if epCfg, ok := s.app.Config.Endpoints[req.EndpointName]; ok {
			if epCfg.Connection == nil {
				epCfg.Connection = &contracts.ConnectionConfig{}
			}
			epCfg.Connection.SSHKeyRef = req.Name
			if err := s.app.ConfigMgr.SaveEndpoints(s.app.Config.Endpoints); err != nil {
				return InternalError(ErrConfigSave, "failed to save endpoint config").
					WithCause(err)
			}
		} else {
			s.app.Logger.Warn("key imported but endpoint not found for assignment",
				logger.String("key", req.Name),
				logger.String("endpoint", req.EndpointName),
			)
		}
	}

	s.app.Logger.Info("ssh private key imported to key store",
		logger.String("key", req.Name),
		logger.String("type", keyType),
		logger.String("fingerprint", fingerprint),
	)

	jsonResp(w, keygenResponse{
		KeyName:     req.Name,
		PublicKey:   pubSSH,
		Fingerprint: fingerprint,
		Type:        keyType,
	})
	return nil
}

// --- GET /api/ssh/keys ---

func (s *Server) handleSSHKeys(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodGet {
		return MethodNotAllowed()
	}

	keys := s.app.SSHKeyManager.List()
	if keys == nil {
		keys = []*contracts.SSHKeyEntry{}
	}

	// Map to response type
	result := make([]sshKeyInfo, 0, len(keys))
	for _, k := range keys {
		result = append(result, sshKeyInfo{
			Name:        k.Name,
			Type:        k.KeyType,
			Fingerprint: k.Fingerprint,
			PublicKey:   k.PublicKey,
		})
	}

	jsonResp(w, result)
	return nil
}

// --- DELETE /api/ssh/keys/{name} ---

func (s *Server) handleSSHKeyDelete(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodDelete {
		return MethodNotAllowed()
	}

	keyName := r.PathValue("name")
	if keyName == "" {
		return ValidationError(ErrMissingField, "key name is required").
			WithDetail("field", "name")
	}

	// Check if key exists
	if _, ok := s.app.SSHKeyManager.Get(keyName); !ok {
		return NotFoundError(ErrSSHKeyNotFound, "SSH key not found: "+keyName).
			WithDetail("key", keyName)
	}

	// Delete from key store
	if err := s.app.SSHKeyManager.Delete(keyName); err != nil {
		return InternalError(ErrConfigSave, "failed to delete SSH key").
			WithCause(err)
	}

	// Clear references from all endpoints
	refsCleared := false
	for _, ep := range s.app.Config.Endpoints {
		if ep.Connection != nil && ep.Connection.SSHKeyRef == keyName {
			ep.Connection.SSHKeyRef = ""
			refsCleared = true
		}
	}
	if refsCleared {
		if err := s.app.ConfigMgr.SaveEndpoints(s.app.Config.Endpoints); err != nil {
			s.app.Logger.Warn("key deleted but failed to save endpoint refs",
				logger.String("key", keyName),
				logger.Error(err),
			)
		}
	}

	s.app.Logger.Info("SSH key deleted",
		logger.String("key", keyName),
	)

	w.WriteHeader(http.StatusNoContent)
	return nil
}

// --- POST /api/ssh/authorize ---

func (s *Server) handleSSHAuthorize(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}

	var req authorizeRequest
	if err := decodeJSON(r, &req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body").
			WithDetail("parse_error", err.Error())
	}
	if req.EndpointName == "" {
		return ValidationError(ErrMissingField, "endpoint_name is required").
			WithDetail("field", "endpoint_name")
	}
	if req.Password == "" && req.TransportKeyRef == "" {
		return ValidationError(ErrMissingField, "password or transport_key_ref is required").
			WithDetail("field", "password or transport_key_ref")
	}

	epCfg, ok := s.app.Config.Endpoints[req.EndpointName]
	if !ok {
		return NotFoundError(ErrEndpointNotFound, "endpoint not found: "+req.EndpointName).
			WithDetail("endpoint", req.EndpointName)
	}
	if epCfg.Connection == nil {
		return ValidationError(ErrInvalidValue, "endpoint has no connection config").
			WithDetail("endpoint", req.EndpointName)
	}

	// Resolve key reference: use key_ref from request, or fall back to endpoint's SSHKeyRef
	keyRef := req.KeyRef
	if keyRef == "" {
		keyRef = epCfg.Connection.SSHKeyRef
	}
	if keyRef == "" {
		return ValidationError(ErrInvalidValue, "no SSH key referenced").
			WithDetail("endpoint", req.EndpointName)
	}

	keyEntry, ok := s.app.SSHKeyManager.Get(keyRef)
	if !ok {
		return NotFoundError(ErrSSHKeyNotFound, "SSH key not found: "+keyRef).
			WithDetail("key", keyRef)
	}
	if keyEntry.PublicKey == "" {
		return InternalError(ErrInternal, "SSH key has no public key").
			WithDetail("key", keyRef)
	}

	conn := epCfg.Connection

	// Build SSH client config
	sshUser := conn.SSHUser
	if sshUser == "" {
		sshUser = "root"
	}

	sshConfig := &gossh.ClientConfig{
		User:            sshUser,
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
	}

	// Determine auth method
	if req.TransportKeyRef != "" {
		pk, ok := s.app.SSHKeyManager.GetPrivateKey(req.TransportKeyRef)
		if !ok {
			return ValidationError(ErrInvalidValue, "transport key not found").
				WithDetail("transport_key_ref", req.TransportKeyRef)
		}
		signer, err := gossh.ParsePrivateKey([]byte(pk))
		if err != nil {
			return ValidationError(ErrInvalidValue, "failed to parse transport key").
				WithCause(err)
		}
		sshConfig.Auth = []gossh.AuthMethod{gossh.PublicKeys(signer)}
	} else if req.Password != "" {
		sshConfig.Auth = []gossh.AuthMethod{gossh.Password(req.Password)}
	} else {
		return ValidationError(ErrMissingField, "password or transport_key_ref is required")
	}

	// Parse host:port from endpoint
	host := conn.Endpoint
	port := 22
	if parts := strings.Split(host, ":"); len(parts) == 2 {
		host = parts[0]
		if p, err := strconv.Atoi(parts[1]); err == nil {
			port = p
		}
	}
	addr := net.JoinHostPort(host, strconv.Itoa(port))

	client, err := gossh.Dial("tcp", addr, sshConfig)
	if err != nil {
		return InternalError(ErrInternal, fmt.Sprintf("SSH connection failed: %v", err)).
			WithCause(err)
	}
	defer client.Close()

	// Create ~/.ssh if needed and append public key
	session, err := client.NewSession()
	if err != nil {
		return InternalError(ErrInternal, "failed to create SSH session").
			WithCause(err)
	}
	defer session.Close()

	cmd := fmt.Sprintf("mkdir -p ~/.ssh && echo '%s' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys",
		strings.ReplaceAll(keyEntry.PublicKey, "'", "'\\''"))
	if err := session.Run(cmd); err != nil {
		return InternalError(ErrInternal, "failed to install public key").
			WithCause(err)
	}

	s.app.Logger.Info("SSH public key authorized",
		logger.String("endpoint", req.EndpointName),
		logger.String("host", addr),
		logger.String("user", sshUser),
		logger.String("key", keyRef),
		logger.String("fingerprint", keyEntry.Fingerprint),
	)

	// Refresh endpoints so the runtime reconnects using the now-authorized key
	s.app.RefreshEndpoints()

	jsonResp(w, map[string]string{"status": "ok"})
	return nil
}

// --- Helper functions ---

// sshExtractPublicKey parses a PEM-encoded private key and returns the SSH public key.
func sshExtractPublicKey(pemData string) (gossh.PublicKey, error) {
	parsed, err := gossh.ParseRawPrivateKey([]byte(pemData))
	if err != nil {
		return nil, err
	}
	switch key := parsed.(type) {
	case ed25519.PrivateKey:
		return gossh.NewPublicKey(key.Public())
	case *ed25519.PrivateKey:
		return gossh.NewPublicKey(key.Public())
	case *rsa.PrivateKey:
		return gossh.NewPublicKey(&key.PublicKey)
	case *ecdsa.PrivateKey:
		return gossh.NewPublicKey(&key.PublicKey)
	default:
		return nil, errUnsupportedKey()
	}
}

func sshKeyTypeName(algo string) string {
	switch algo {
	case gossh.KeyAlgoED25519:
		return "ed25519"
	case gossh.KeyAlgoRSA:
		return "rsa"
	case gossh.KeyAlgoECDSA256:
		return "ecdsa-p256"
	case gossh.KeyAlgoECDSA384:
		return "ecdsa-p384"
	case gossh.KeyAlgoECDSA521:
		return "ecdsa-p521"
	default:
		return algo
	}
}

func generateSSHKeyPair(keyType string) (interface{}, gossh.PublicKey, error) {
	switch keyType {
	case "ed25519":
		pub, priv, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return nil, nil, err
		}
		sshPub, err := gossh.NewPublicKey(pub)
		if err != nil {
			return nil, nil, err
		}
		return priv, sshPub, nil

	case "rsa-2048":
		return generateRSA(2048)
	case "rsa-4096":
		return generateRSA(4096)

	case "ecdsa-p256":
		return generateECDSA(elliptic.P256())
	case "ecdsa-p384":
		return generateECDSA(elliptic.P384())

	default:
		return nil, nil, errInvalidKeyType(keyType)
	}
}

func generateRSA(bits int) (interface{}, gossh.PublicKey, error) {
	priv, err := rsa.GenerateKey(rand.Reader, bits)
	if err != nil {
		return nil, nil, err
	}
	sshPub, err := gossh.NewPublicKey(&priv.PublicKey)
	if err != nil {
		return nil, nil, err
	}
	return priv, sshPub, nil
}

func generateECDSA(curve elliptic.Curve) (interface{}, gossh.PublicKey, error) {
	priv, err := ecdsa.GenerateKey(curve, rand.Reader)
	if err != nil {
		return nil, nil, err
	}
	sshPub, err := gossh.NewPublicKey(&priv.PublicKey)
	if err != nil {
		return nil, nil, err
	}
	return priv, sshPub, nil
}

type keyTypeError struct{ t string }

func (e *keyTypeError) Error() string {
	return "unsupported key type: " + e.t + " (supported: ed25519, rsa-2048, rsa-4096, ecdsa-p256, ecdsa-p384)"
}

func errInvalidKeyType(t string) error {
	return &keyTypeError{t: t}
}

type unsupportedKeyError struct{}

func (e *unsupportedKeyError) Error() string { return "unsupported key type" }
func errUnsupportedKey() error               { return &unsupportedKeyError{} }

func decodeJSON(r *http.Request, v interface{}) error {
	return json.NewDecoder(r.Body).Decode(v)
}
