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

	// Ensure config directory exists
	os.MkdirAll(filepath.Join(dir, "config"), 0755)

	cfgLoader := config.NewLoader()
	cfgMgr := core.NewConfigManager(cfgLoader, dir)
	cfgMgr.SaveEndpoints(make(map[string]*contracts.EndpointConfig))

	// Initialize SSH key manager
	keyMgr := core.NewSSHKeyManager(filepath.Join(dir, "config", "ssh_keys.yaml"))

	app := &core.App{
		Config: &contracts.AppConfig{
			BaseDataDir: dir,
		},
		ConfigMgr:     cfgMgr,
		SSHKeyManager: keyMgr,
		Logger:        logger.NewNop(),
	}
	return app
}

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

// --- Keygen Tests ---

func TestSSHKeygen_Success(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"name":"test-key","type":"ed25519"}`
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
		t.Errorf("expected type 'ed25519', got %q", resp.Type)
	}
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
	if resp.KeyName != "test-key" {
		t.Errorf("expected KeyName 'test-key', got %q", resp.KeyName)
	}

	// Verify key was stored in key store
	entry, ok := app.SSHKeyManager.Get("test-key")
	if !ok {
		t.Fatal("key 'test-key' should exist in key store")
	}
	if entry.PublicKey == "" {
		t.Error("stored key should have a public key")
	}
	if entry.Fingerprint == "" {
		t.Error("stored key should have a fingerprint")
	}

	// Verify private key is NOT exposed in Get (stripped for safety)
	if entry.PrivateKey != "" {
		t.Error("Get() should return key without PrivateKey")
	}

	// Verify private key IS stored in key manager (via GetPrivateKey)
	pk, ok := app.SSHKeyManager.GetPrivateKey("test-key")
	if !ok || pk == "" {
		t.Error("private key should be retrievable via GetPrivateKey")
	}
	if !strings.Contains(pk, "PRIVATE KEY") {
		t.Error("stored private key should be PEM-encoded")
	}
}

func TestSSHKeygen_WithEndpointName(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "myserver")
	srv := New(app)
	handler := srv.Handler()

	body := `{"name":"mykey","endpoint_name":"myserver","type":"ed25519"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Verify key was stored in key store
	if _, ok := app.SSHKeyManager.Get("mykey"); !ok {
		t.Fatal("key 'mykey' should exist in key store")
	}

	// Verify endpoint has SSHKeyRef set
	ep := app.Config.Endpoints["myserver"]
	if ep.Connection.SSHKeyRef != "mykey" {
		t.Errorf("expected SSHKeyRef 'mykey', got %q", ep.Connection.SSHKeyRef)
	}

	// Verify SSHPrivateKey is NOT set in endpoint config
	if ep.Connection.SSHPrivateKey != "" {
		t.Error("SSHPrivateKey should not be set in endpoint config")
	}
}

func TestSSHKeygen_RSA2048(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"name":"rsa-key","type":"rsa-2048"}`
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

	// Verify via GetPrivateKey
	pk, ok := app.SSHKeyManager.GetPrivateKey("rsa-key")
	if !ok || pk == "" {
		t.Error("private key should be retrievable via GetPrivateKey")
	}
}

func TestSSHKeygen_ECDSAP256(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"name":"ecdsa-key","type":"ecdsa-p256"}`
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

func TestSSHKeygen_MissingName(t *testing.T) {
	app := newTestApp(t)
	srv := New(app)
	handler := srv.Handler()

	body := `{"type":"ed25519"}`
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

func TestSSHKeygen_EndpointNotFoundIsOkay(t *testing.T) {
	app := newTestApp(t)
	// No endpoints seeded — keygen without endpoint_name should still succeed
	srv := New(app)
	handler := srv.Handler()

	body := `{"name":"standalone-key","type":"ed25519"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 (keygen without endpoint should succeed), got %d: %s", w.Code, w.Body.String())
	}
}

func TestSSHKeygen_InvalidType(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"name":"test","type":"dsa-1024"}`
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

	body := `{"name":"default-key","type":""}`
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

	body := `{"name":"rsa4096-key","type":"rsa-4096"}`
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

// --- Key List Tests ---

func TestSSHKeys_ListFromStore(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "myserver")
	srv := New(app)
	handler := srv.Handler()

	// Generate a key (without endpoint assignment)
	body := `{"name":"mykey","type":"ed25519"}`
	genReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	genW := httptest.NewRecorder()
	handler.ServeHTTP(genW, genReq)
	if genW.Code != http.StatusOK {
		t.Fatalf("keygen failed: %d: %s", genW.Code, genW.Body.String())
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

	found := false
	for _, k := range keys {
		if k.Name == "mykey" {
			found = true
			if k.Fingerprint == "" {
				t.Error("fingerprint should not be empty")
			}
			if k.PublicKey == "" {
				t.Error("public_key should not be empty")
			}
			break
		}
	}
	if !found {
		t.Error("expected 'mykey' in key list")
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

// --- Key Delete Tests ---

func TestSSHKeyDelete_Success(t *testing.T) {
	app := newTestApp(t)
	srv := New(app)
	handler := srv.Handler()

	// Create a key first
	body := `{"name":"delete-me","type":"ed25519"}`
	genReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	genW := httptest.NewRecorder()
	handler.ServeHTTP(genW, genReq)
	if genW.Code != http.StatusOK {
		t.Fatalf("keygen failed: %d", genW.Code)
	}

	// Delete it
	delReq := newAuthRequest(t, srv, http.MethodDelete, "/api/ssh/keys/delete-me", nil)
	delW := httptest.NewRecorder()
	handler.ServeHTTP(delW, delReq)

	if delW.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d: %s", delW.Code, delW.Body.String())
	}

	// Verify key is gone
	if _, ok := app.SSHKeyManager.Get("delete-me"); ok {
		t.Error("key should be deleted from key store")
	}
}

func TestSSHKeyDelete_ReferencedKey(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "myserver")
	srv := New(app)
	handler := srv.Handler()

	// Create key with endpoint assignment
	body := `{"name":"assigned-key","endpoint_name":"myserver","type":"ed25519"}`
	genReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(body))
	genW := httptest.NewRecorder()
	handler.ServeHTTP(genW, genReq)
	if genW.Code != http.StatusOK {
		t.Fatalf("keygen failed: %d", genW.Code)
	}

	// Verify SSHKeyRef is set
	if app.Config.Endpoints["myserver"].Connection.SSHKeyRef != "assigned-key" {
		t.Fatal("expected endpoint to reference the key")
	}

	// Delete the key
	delReq := newAuthRequest(t, srv, http.MethodDelete, "/api/ssh/keys/assigned-key", nil)
	delW := httptest.NewRecorder()
	handler.ServeHTTP(delW, delReq)

	if delW.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d: %s", delW.Code, delW.Body.String())
	}

	// Verify endpoint's SSHKeyRef was cleared
	if app.Config.Endpoints["myserver"].Connection.SSHKeyRef != "" {
		t.Error("endpoint SSHKeyRef should be cleared after key deletion")
	}
}

func TestSSHKeyDelete_NotFound(t *testing.T) {
	app := newTestApp(t)
	srv := New(app)
	handler := srv.Handler()

	delReq := newAuthRequest(t, srv, http.MethodDelete, "/api/ssh/keys/nonexistent", nil)
	delW := httptest.NewRecorder()
	handler.ServeHTTP(delW, delReq)

	if delW.Code != 404 {
		t.Fatalf("expected 404, got %d: %s", delW.Code, delW.Body.String())
	}
}

// --- Import Tests ---

func TestSSHImport_Success(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	// First generate a key to use as import source
	genBody := `{"name":"source","type":"ed25519"}`
	genReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(genBody))
	genW := httptest.NewRecorder()
	handler.ServeHTTP(genW, genReq)
	if genW.Code != http.StatusOK {
		t.Fatalf("keygen failed: %d", genW.Code)
	}

	privKey, _ := app.SSHKeyManager.GetPrivateKey("source")

	// Now import that key
	importBody := `{"name":"imported","private_key":"` + strings.ReplaceAll(privKey, "\n", "\\n") + `"}`
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

	// Verify key is in store
	if _, ok := app.SSHKeyManager.Get("imported"); !ok {
		t.Error("imported key should exist in key store")
	}
}

func TestSSHImport_InvalidKey(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "default")
	srv := New(app)
	handler := srv.Handler()

	body := `{"name":"bad","private_key":"not-a-real-key"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/import", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != 400 {
		t.Fatalf("expected 400, got %d: %s", w.Code, w.Body.String())
	}
}

func TestSSHImport_WithEndpointName(t *testing.T) {
	app := newTestApp(t)
	seedEndpoint(app, "myserver")
	srv := New(app)
	handler := srv.Handler()

	// Generate source key
	genBody := `{"name":"src","type":"ed25519"}`
	genReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/keygen", strings.NewReader(genBody))
	genW := httptest.NewRecorder()
	handler.ServeHTTP(genW, genReq)
	if genW.Code != http.StatusOK {
		t.Fatalf("keygen failed: %d", genW.Code)
	}

	privKey, _ := app.SSHKeyManager.GetPrivateKey("src")

	// Import with endpoint assignment
	importBody := `{"name":"imported-key","endpoint_name":"myserver","private_key":"` + strings.ReplaceAll(privKey, "\n", "\\n") + `"}`
	importReq := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/import", strings.NewReader(importBody))
	importW := httptest.NewRecorder()
	handler.ServeHTTP(importW, importReq)

	if importW.Code != http.StatusOK {
		t.Fatalf("import expected 200, got %d: %s", importW.Code, importW.Body.String())
	}

	// Verify endpoint SSHKeyRef
	if app.Config.Endpoints["myserver"].Connection.SSHKeyRef != "imported-key" {
		t.Errorf("expected SSHKeyRef 'imported-key', got %q", app.Config.Endpoints["myserver"].Connection.SSHKeyRef)
	}
}

func TestSSHImport_MissingName(t *testing.T) {
	app := newTestApp(t)
	srv := New(app)
	handler := srv.Handler()

	body := `{"private_key":"some-key"}`
	req := newAuthRequest(t, srv, http.MethodPost, "/api/ssh/import", strings.NewReader(body))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != 400 {
		t.Fatalf("expected 400, got %d: %s", w.Code, w.Body.String())
	}
}
