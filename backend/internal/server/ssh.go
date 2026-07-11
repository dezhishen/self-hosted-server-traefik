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
	"net/http"

	"go.uber.org/zap"
	"golang.org/x/crypto/ssh"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

type keygenRequest struct {
	// Which endpoint to associate the key with.
	EndpointName string `json:"endpoint_name"`
	// Display name for the key (informational only).
	Name string `json:"name"`
	// Key type: ed25519 (default), rsa-2048, rsa-4096, ecdsa-p256, ecdsa-p384.
	Type string `json:"type"`
}

type keygenResponse struct {
	Name        string `json:"name"`
	KeyName     string `json:"key_name"`
	PublicKey   string `json:"public_key"`
	Fingerprint string `json:"fingerprint"`
	Type        string `json:"type"`
}

type sshKeyInfo struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Fingerprint string `json:"fingerprint"`
	PublicKey   string `json:"public_key"`
}

// POST /api/ssh/keygen
// Body: { "endpoint_name": "default", "name": "my-key", "type": "ed25519" }
// Generates an SSH key pair, stores the private key in the endpoint's connection
// config (server-side only), and returns public key info to the caller.
// The private key is NEVER exposed via JSON to the frontend.
func (s *Server) handleSSHKeygen(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonErr(w, 405, "method not allowed")
		return
	}

	var req keygenRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonErr(w, 400, "invalid request body: "+err.Error())
		return
	}
	if req.EndpointName == "" {
		jsonErr(w, 400, "endpoint_name is required")
		return
	}
	if req.Type == "" {
		req.Type = "ed25519"
	}

	// Validate endpoint exists
	epCfg, ok := s.app.Config.Endpoints[req.EndpointName]
	if !ok {
		jsonErr(w, 404, "endpoint not found: "+req.EndpointName)
		return
	}
	if epCfg.Connection == nil {
		epCfg.Connection = &contracts.ConnectionConfig{}
	}

	privKey, pubKey, err := generateSSHKeyPair(req.Type)
	if err != nil {
		jsonErr(w, 400, err.Error())
		return
	}

	// Marshal private key to PEM — store server-side only
	privBytes, err := x509.MarshalPKCS8PrivateKey(privKey)
	if err != nil {
		jsonErr(w, 500, "failed to marshal private key: "+err.Error())
		return
	}
	privPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: privBytes,
	})

	// Store private key in endpoint config (never serialized to JSON)
	epCfg.Connection.SSHPrivateKey = string(privPEM)
	pubSSH := string(ssh.MarshalAuthorizedKey(pubKey))
	epCfg.Connection.SSHPublicKey = pubSSH
	epCfg.Connection.SSHKeyFingerprint = ssh.FingerprintSHA256(pubKey)
	epCfg.Connection.SSHKeyType = req.Type

	// Persist to disk
	if err := s.app.ConfigMgr.SaveEndpoints(s.app.Config.Endpoints); err != nil {
		jsonErr(w, 500, "failed to save config: "+err.Error())
		return
	}

	// Refresh endpoint contexts to pick up the new SSH key
	s.app.RefreshEndpoints()

	s.app.Logger.Info("ssh key pair generated and stored server-side",
		zap.String("endpoint", req.EndpointName),
		zap.String("name", req.Name),
		zap.String("type", req.Type),
		zap.String("fingerprint", epCfg.Connection.SSHKeyFingerprint),
	)

	jsonResp(w, keygenResponse{
		Name:        req.EndpointName,
		KeyName:     req.Name,
		PublicKey:   pubSSH,
		Fingerprint: epCfg.Connection.SSHKeyFingerprint,
		Type:        req.Type,
	})
}

type sshImportRequest struct {
	EndpointName string `json:"endpoint_name"`
	PrivateKey   string `json:"private_key"`
}

// POST /api/ssh/import
// Body: { "endpoint_name": "default", "private_key": "-----BEGIN PRIVATE KEY-----..." }
// Imports an existing SSH private key, stores it server-side, validates it,
// and returns public key info. The private key is NEVER exposed via JSON.
func (s *Server) handleSSHImport(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonErr(w, 405, "method not allowed")
		return
	}

	var req sshImportRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonErr(w, 400, "invalid request body: "+err.Error())
		return
	}
	if req.EndpointName == "" {
		jsonErr(w, 400, "endpoint_name is required")
		return
	}
	if req.PrivateKey == "" {
		jsonErr(w, 400, "private_key is required")
		return
	}

	// Validate the private key by extracting the public key
	pubKey, err := sshExtractPublicKey(req.PrivateKey)
	if err != nil {
		jsonErr(w, 400, "invalid private key: "+err.Error())
		return
	}

	// Ensure endpoint exists
	epCfg, ok := s.app.Config.Endpoints[req.EndpointName]
	if !ok {
		jsonErr(w, 404, "endpoint not found: "+req.EndpointName)
		return
	}
	if epCfg.Connection == nil {
		epCfg.Connection = &contracts.ConnectionConfig{}
	}

	// Store private key in endpoint config
	epCfg.Connection.SSHPrivateKey = req.PrivateKey
	pubSSH := string(ssh.MarshalAuthorizedKey(pubKey))
	epCfg.Connection.SSHPublicKey = pubSSH
	epCfg.Connection.SSHKeyFingerprint = ssh.FingerprintSHA256(pubKey)
	epCfg.Connection.SSHKeyType = sshKeyTypeName(pubKey.Type())

	// Persist to disk
	if err := s.app.ConfigMgr.SaveEndpoints(s.app.Config.Endpoints); err != nil {
		jsonErr(w, 500, "failed to save config: "+err.Error())
		return
	}

	// Refresh endpoint contexts
	s.app.RefreshEndpoints()

	s.app.Logger.Info("ssh private key imported",
		zap.String("endpoint", req.EndpointName),
		zap.String("type", epCfg.Connection.SSHKeyType),
		zap.String("fingerprint", epCfg.Connection.SSHKeyFingerprint),
	)

	jsonResp(w, keygenResponse{
		Name:        req.EndpointName,
		KeyName:     "", // imported, no name
		PublicKey:   pubSSH,
		Fingerprint: epCfg.Connection.SSHKeyFingerprint,
		Type:        epCfg.Connection.SSHKeyType,
	})
}

// computeSSHKeyMeta derives the SSH key fingerprint, type, and public key from
// the private key stored in a connection config.
// Sets the read-only fields SSHKeyFingerprint, SSHKeyType, and SSHPublicKey.
func computeSSHKeyMeta(conn *contracts.ConnectionConfig) {
	if conn.SSHPrivateKey == "" {
		conn.SSHKeyFingerprint = ""
		conn.SSHKeyType = ""
		conn.SSHPublicKey = ""
		return
	}
	pubKey, err := sshExtractPublicKey(conn.SSHPrivateKey)
	if err != nil {
		conn.SSHKeyFingerprint = ""
		conn.SSHKeyType = ""
		conn.SSHPublicKey = ""
		return
	}
	conn.SSHKeyFingerprint = ssh.FingerprintSHA256(pubKey)
	conn.SSHKeyType = sshKeyTypeName(pubKey.Type())
	conn.SSHPublicKey = string(ssh.MarshalAuthorizedKey(pubKey))
}

// GET /api/ssh/keys
// Returns list of SSH keys by scanning endpoints config for inline SSH keys.
func (s *Server) handleSSHKeys(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonErr(w, 405, "method not allowed")
		return
	}

	var keys []sshKeyInfo
	seen := make(map[string]bool)

	for name, ep := range s.app.Config.Endpoints {
		if ep.Connection == nil || ep.Connection.SSHPrivateKey == "" {
			continue
		}
		if seen[name] {
			continue
		}
		seen[name] = true

		// Parse public key from the private key to get fingerprint
		pubKey, err := sshExtractPublicKey(ep.Connection.SSHPrivateKey)
		if err != nil {
			// Just show what we can
			keys = append(keys, sshKeyInfo{
				Name: name,
				Type: "unknown",
			})
			continue
		}

		keys = append(keys, sshKeyInfo{
			Name:        name,
			Type:        sshKeyTypeName(pubKey.Type()),
			Fingerprint: ssh.FingerprintSHA256(pubKey),
			PublicKey:   string(ssh.MarshalAuthorizedKey(pubKey)),
		})
	}

	if keys == nil {
		keys = []sshKeyInfo{}
	}
	jsonResp(w, keys)
}

// sshExtractPublicKey parses a PEM-encoded private key and returns its SSH public key.
func sshExtractPublicKey(pemData string) (ssh.PublicKey, error) {
	parsed, err := ssh.ParseRawPrivateKey([]byte(pemData))
	if err != nil {
		return nil, err
	}
	switch key := parsed.(type) {
	case ed25519.PrivateKey:
		return ssh.NewPublicKey(key.Public())
	case *ed25519.PrivateKey:
		return ssh.NewPublicKey(key.Public())
	case *rsa.PrivateKey:
		return ssh.NewPublicKey(&key.PublicKey)
	case *ecdsa.PrivateKey:
		return ssh.NewPublicKey(&key.PublicKey)
	default:
		return nil, errUnsupportedKey()
	}
}

func sshKeyTypeName(algo string) string {
	switch algo {
	case ssh.KeyAlgoED25519:
		return "ed25519"
	case ssh.KeyAlgoRSA:
		return "rsa"
	case ssh.KeyAlgoECDSA256:
		return "ecdsa-p256"
	case ssh.KeyAlgoECDSA384:
		return "ecdsa-p384"
	case ssh.KeyAlgoECDSA521:
		return "ecdsa-p521"
	default:
		return algo
	}
}

func generateSSHKeyPair(keyType string) (interface{}, ssh.PublicKey, error) {
	switch keyType {
	case "ed25519":
		pub, priv, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return nil, nil, err
		}
		sshPub, err := ssh.NewPublicKey(pub)
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

func generateRSA(bits int) (interface{}, ssh.PublicKey, error) {
	priv, err := rsa.GenerateKey(rand.Reader, bits)
	if err != nil {
		return nil, nil, err
	}
	sshPub, err := ssh.NewPublicKey(&priv.PublicKey)
	if err != nil {
		return nil, nil, err
	}
	return priv, sshPub, nil
}

func generateECDSA(curve elliptic.Curve) (interface{}, ssh.PublicKey, error) {
	priv, err := ecdsa.GenerateKey(curve, rand.Reader)
	if err != nil {
		return nil, nil, err
	}
	sshPub, err := ssh.NewPublicKey(&priv.PublicKey)
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
