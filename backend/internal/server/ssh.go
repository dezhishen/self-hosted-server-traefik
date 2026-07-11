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
	EndpointName string `json:"endpoint_name"`
	Name         string `json:"name"`
	Type         string `json:"type"`
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
func (s *Server) handleSSHKeygen(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}

	var req keygenRequest
	if err := decodeJSON(r, &req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body").
			WithDetail("parse_error", err.Error())
	}
	if req.EndpointName == "" {
		return ValidationError(ErrMissingField, "endpoint_name is required").
			WithDetail("field", "endpoint_name")
	}
	if req.Type == "" {
		req.Type = "ed25519"
	}

	epCfg, ok := s.app.Config.Endpoints[req.EndpointName]
	if !ok {
		return NotFoundError(ErrEndpointNotFound, "endpoint not found: "+req.EndpointName).
			WithDetail("endpoint", req.EndpointName)
	}
	if epCfg.Connection == nil {
		epCfg.Connection = &contracts.ConnectionConfig{}
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

	epCfg.Connection.SSHPrivateKey = string(privPEM)
	pubSSH := string(ssh.MarshalAuthorizedKey(pubKey))
	epCfg.Connection.SSHPublicKey = pubSSH
	epCfg.Connection.SSHKeyFingerprint = ssh.FingerprintSHA256(pubKey)
	epCfg.Connection.SSHKeyType = req.Type

	if err := s.app.ConfigMgr.SaveEndpoints(s.app.Config.Endpoints); err != nil {
		return InternalError(ErrConfigSave, "failed to save config").
			WithCause(err)
	}

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
	return nil
}

type sshImportRequest struct {
	EndpointName string `json:"endpoint_name"`
	PrivateKey   string `json:"private_key"`
}

// POST /api/ssh/import
func (s *Server) handleSSHImport(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}

	var req sshImportRequest
	if err := decodeJSON(r, &req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body").
			WithDetail("parse_error", err.Error())
	}
	if req.EndpointName == "" {
		return ValidationError(ErrMissingField, "endpoint_name is required").
			WithDetail("field", "endpoint_name")
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

	epCfg, ok := s.app.Config.Endpoints[req.EndpointName]
	if !ok {
		return NotFoundError(ErrEndpointNotFound, "endpoint not found: "+req.EndpointName).
			WithDetail("endpoint", req.EndpointName)
	}
	if epCfg.Connection == nil {
		epCfg.Connection = &contracts.ConnectionConfig{}
	}

	epCfg.Connection.SSHPrivateKey = req.PrivateKey
	pubSSH := string(ssh.MarshalAuthorizedKey(pubKey))
	epCfg.Connection.SSHPublicKey = pubSSH
	epCfg.Connection.SSHKeyFingerprint = ssh.FingerprintSHA256(pubKey)
	epCfg.Connection.SSHKeyType = sshKeyTypeName(pubKey.Type())

	if err := s.app.ConfigMgr.SaveEndpoints(s.app.Config.Endpoints); err != nil {
		return InternalError(ErrConfigSave, "failed to save config").
			WithCause(err)
	}

	s.app.RefreshEndpoints()

	s.app.Logger.Info("ssh private key imported",
		zap.String("endpoint", req.EndpointName),
		zap.String("type", epCfg.Connection.SSHKeyType),
		zap.String("fingerprint", epCfg.Connection.SSHKeyFingerprint),
	)

	jsonResp(w, keygenResponse{
		Name:        req.EndpointName,
		KeyName:     "",
		PublicKey:   pubSSH,
		Fingerprint: epCfg.Connection.SSHKeyFingerprint,
		Type:        epCfg.Connection.SSHKeyType,
	})
	return nil
}

// computeSSHKeyMeta 从连接配置中的私钥派生 SSH 密钥元信息。
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
func (s *Server) handleSSHKeys(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodGet {
		return MethodNotAllowed()
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

		pubKey, err := sshExtractPublicKey(ep.Connection.SSHPrivateKey)
		if err != nil {
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
	return nil
}

// ssh 密钥解析与生成（保持不变）
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
