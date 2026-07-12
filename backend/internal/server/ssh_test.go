package server

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"github.com/dezhishen/self-hosted-server-traefik/backend/config"
	"github.com/dezhishen/self-hosted-server-traefik/backend/core"
	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
)

func newTestApp(t *testing.T) *core.App {
	t.Helper()
	dir := t.TempDir()

	// Ensure config directory exists (SaveEndpoints writes to config/endpoints.yaml)
	os.MkdirAll(filepath.Join(dir, "config"), 0755)

	cfgLoader := config.NewLoader()
	cfgMgr := core.NewConfigManager(cfgLoader, dir)
	// Seed config with empty endpoints so ConfigMgr has a valid path
	cfgMgr.SaveEndpoints(make(map[string]*contracts.EndpointConfig))

	app := &core.App{
		Config: &contracts.AppConfig{
			BaseDataDir: dir,
		},
		ConfigMgr: cfgMgr,
		Logger:    logger.NewNop(),
	}
	return app
}

// newAuthRequest creates an HTTP request with a valid session token for testing auth-protected routes.
func newAuthRequest(t *testing.T, srv *Server, method, path string, body io.Reader) *http.Request {
	t.Helper()
	token, err := srv.sessions.CreateSession("test")
	if err != nil {
		t.Fatalf("failed to create session: %v", err)
	}
	req := httptest.NewRequest(method, path, body)
	req.Header.Set("Authorization", "Bearer "+token)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	return req
}

func seedEndpoint(app *core.App, name string) {
	if app.Config.Endpoints == nil {
		app.Config.Endpoints = make(map[string]*contracts.EndpointConfig)
	}
	app.Config.Endpoints[name] = &contracts.EndpointConfig{
		Name:    name,
		Default: true,
		Connection: &contracts.ConnectionConfig{
			Type:     "ssh",
			Endpoint: "192.168.1.100:22",
		},
	}
}

func TestSSHKeygen_Success(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"default","name":"test-key","type":"ed25519"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp keygenResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Name != "default" {
		t.Errorf("expected name 'default', got %q", resp.Name)
	}
	if resp.Type != "ed25519" {
		t.Errorf("expected type 'ed25519', got %q", resp.Type)
	}
	// Private key is NEVER returned to frontend
	if resp.PublicKey == "" {
		t.Error("public_key should not be empty")
	}
	if !strings.HasPrefix(resp.PublicKey, "ssh-ed25519") {
		t.Errorf("expected public_key to start with 'ssh-ed25519', got %q", resp.PublicKey[:20])
	}
	if resp.Fingerprint == "" {
		t.Error("fingerprint should not be empty")
	}
	if !strings.HasPrefix(resp.Fingerprint, "SHA256:") {
		t.Errorf("expected fingerprint to start with 'SHA256:', got %q", resp.Fingerprint)
	}
	// Verify key was stored server-side in endpoint config
	if app.Config.Endpoints["default"].Connection.SSHPrivateKey == "" {
		t.Error("private key should be stored in endpoint config")
	}
	if !strings.Contains(app.Config.Endpoints["default"].Connection.SSHPrivateKey, "PRIVATE KEY") {
		t.Error("stored private key should be PEM-encoded")
	}
}

func TestSSHKeygen_RSA2048(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"default","name":"rsa-key","type":"rsa-2048"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp keygenResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Type != "rsa-2048" {
		t.Errorf("expected type 'rsa-2048', got %q", resp.Type)
	}
	if resp.PublicKey == "" {
		t.Error("public_key should not be empty")
	}
	if !strings.HasPrefix(resp.PublicKey, "ssh-rsa") {
		t.Errorf("expected public_key to start with 'ssh-rsa', got %q", resp.PublicKey[:15])
	}
	if resp.Fingerprint == "" {
		t.Error("fingerprint should not be empty")
	}
	// Verify key stored server-side
	if app.Config.Endpoints["default"].Connection.SSHPrivateKey == "" {
		t.Error("private key should be stored in endpoint config")
	}
}

func TestSSHKeygen_ECDSAP256(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"default","name":"ecdsa-key","type":"ecdsa-p256"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp keygenResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Type != "ecdsa-p256" {
		t.Errorf("expected type 'ecdsa-p256', got %q", resp.Type)
	}
	if resp.PublicKey == "" {
		t.Error("public_key should not be empty")
	}
	if !strings.HasPrefix(resp.PublicKey, "ecdsa-sha2-nistp256") {
		t.Errorf("expected ecdsa-sha2-nistp256 public key, got %q", resp.PublicKey[:25])
	}
}

func TestSSHKeygen_MissingEndpointName(t *testing.T) {
	app := newTestApp(t)
	srv := New(app)
	handler := srv.Handler()

	body := `{"name":"test","type":"ed25519"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != 400 {
		t.Fatalf("expected 400, got %d: %s", w.Code, w.Body.String())
	}

	var errResp struct {
		Error *APIError `json:"error"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &errResp); err != nil {
		t.Fatalf("failed to unmarshal error: %v", err)
	}
	if errResp.Error == nil || errResp.Error.Message == "" {
		t.Error("expected error message")
	}
}

func TestSSHKeygen_EndpointNotFound(t *testing.T) {
	app := newTestApp(t)
	// No endpoints seeded
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"nonexistent","type":"ed25519"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != 404 {
		t.Fatalf("expected 404, got %d: %s", w.Code, w.Body.String())
	}
}

func TestSSHKeygen_InvalidType(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"default","name":"test","type":"dsa-1024"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != 400 {
		t.Fatalf("expected 400, got %d: %s", w.Code, w.Body.String())
	}
}

func TestSSHKeygen_MethodNotAllowed(t *testing.T) {
	app := newTestApp(t)
	srv := New(app)
	handler := srv.Handler()

	req := newAuthRequest(t, srv, http.MethodGet, "/api/ssh/keygen", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != 405 {
		t.Fatalf("expected 405, got %d: %s", w.Code, w.Body.String())
	}
}

func TestSSHKeygen_DefaultType(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"default","name":"default-key","type":""}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp keygenResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Type != "ed25519" {
		t.Errorf("expected default type 'ed25519', got %q", resp.Type)
	}
}

func TestSSHKeygen_RSA4096(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"default","name":"rsa4096-key","type":"rsa-4096"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp keygenResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Type != "rsa-4096" {
		t.Errorf("expected type 'rsa-4096', got %q", resp.Type)
	}
	if !strings.HasPrefix(resp.PublicKey, "ssh-rsa") {
		t.Errorf("expected ssh-rsa public key, got %q", resp.PublicKey[:15])
	}
}

func TestSSHKeys_ListFromConfig(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "myserver")

	// Generate key — stores it server-side in the endpoint config
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"myserver","name":"mykey","type":"ed25519"}`
	genReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	genW := httptest.NewRecorder()
	handler.ServeHTTP(genW, genReq)
	if genW.Code != http.StatusOK {
		t.Fatalf("keygen failed: %d: %s", genW.Code, genW.Body.String())
	}

	// Verify the key was stored server-side
	if app.Config.Endpoints["myserver"].Connection.SSHPrivateKey == "" {
		t.Fatal("private key was not stored in endpoint config")
	}

	// List keys
	req := newAuthRequest(t, srv, http.MethodGet, "/api/ssh/keys", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var keys []sshKeyInfo
	if err := json.Unmarshal(w.Body.Bytes(), &keys); err != nil {
		t.Fatalf("failed to unmarshal keys: %v", err)
	}

	if len(keys) == 0 {
		t.Fatal("expected at least 1 key")
	}

	if keys[0].Name != "myserver" {
		t.Errorf("expected key name 'myserver', got %q", keys[0].Name)
	}
	if keys[0].Fingerprint == "" {
		t.Error("fingerprint should not be empty")
	}
}

func TestSSHKeys_EmptyList(t *testing.T) {
	app := newTestApp(t)
	srv := New(app)
	handler := srv.Handler()

	req := newAuthRequest(t, srv, http.MethodGet, "/api/ssh/keys", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var keys []sshKeyInfo
	if err := json.Unmarshal(w.Body.Bytes(), &keys); err != nil {
		t.Fatalf("failed to unmarshal keys: %v", err)
	}

	if len(keys) != 0 {
		t.Fatalf("expected empty list, got %d keys", len(keys))
	}
}

func TestSSHImport_Success(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	// First generate a key to use as import source
	genBody := `{"endpoint_name":"default","name":"source","type":"ed25519"}`
	genReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(genBody))
	genW := httptest.NewRecorder()
	handler.ServeHTTP(genW, genReq)
	if genW.Code != http.StatusOK {
		t.Fatalf("keygen failed: %d", genW.Code)
	}

	privKey := app.Config.Endpoints["default"].Connection.SSHPrivateKey

	// Now import that key via the import endpoint
	importBody := `{"endpoint_name":"default","private_key":"` + strings.ReplaceAll(privKey, "\n", "\\n") + `"}`
	importReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/import", strings.NewReader(importBody))
	importW := httptest.NewRecorder()
	handler.ServeHTTP(importW, importReq)

	if importW.Code != http.StatusOK {
		t.Fatalf("import expected 200, got %d: %s", importW.Code, importW.Body.String())
	}

	var resp keygenResponse
	if err := json.Unmarshal(importW.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.PublicKey == "" {
		t.Error("public_key should not be empty")
	}
	if resp.Fingerprint == "" {
		t.Error("fingerprint should not be empty")
	}
}

func TestSSHImport_InvalidKey(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"endpoint_name":"default","private_key":"not-a-real-key"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/import", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != 400 {
		t.Fatalf("expected 400, got %d: %s", w.Code, w.Body.String())
	}
}


