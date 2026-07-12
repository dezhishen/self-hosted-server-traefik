package core

import (
	"path/filepath"
	"testing"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

func newTestKeyManager(t *testing.T) *SSHKeyManager {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "config", "ssh_keys.yaml")
	return NewSSHKeyManager(path)
}

func TestNewSSHKeyManager(t *testing.T) {
	mgr := newTestKeyManager(t)
	if mgr == nil {
		t.Fatal("NewSSHKeyManager should return non-nil")
	}
	if mgr.keys == nil {
		t.Error("internal keys map should be initialized")
	}
}

func TestLoad_NonExistentFile(t *testing.T) {
	mgr := newTestKeyManager(t)
	if err := mgr.Load(); err != nil {
		t.Fatalf("Load on non-existent file should not error: %v", err)
	}
	if len(mgr.keys) != 0 {
		t.Error("keys should be empty after loading non-existent file")
	}
}

func TestSetAndGet(t *testing.T) {
	mgr := newTestKeyManager(t)
	mgr.Load()

	entry := &contracts.SSHKeyEntry{
		Name:        "test-key",
		PrivateKey:  "private-data",
		PublicKey:   "public-data",
		Fingerprint: "SHA256:abc",
		KeyType:     "ed25519",
	}

	if err := mgr.Set(entry); err != nil {
		t.Fatalf("Set failed: %v", err)
	}

	got, ok := mgr.Get("test-key")
	if !ok {
		t.Fatal("Get should return true for existing key")
	}
	if got.PublicKey != "public-data" {
		t.Errorf("expected PublicKey 'public-data', got %q", got.PublicKey)
	}
	// PrivateKey should be stripped in Get
	if got.PrivateKey != "" {
		t.Error("Get should return key without PrivateKey")
	}
}

func TestGetPrivateKey(t *testing.T) {
	mgr := newTestKeyManager(t)
	mgr.Load()

	entry := &contracts.SSHKeyEntry{
		Name:       "test-key",
		PrivateKey: "super-secret",
	}
	mgr.Set(entry)

	pk, ok := mgr.GetPrivateKey("test-key")
	if !ok {
		t.Fatal("GetPrivateKey should return true")
	}
	if pk != "super-secret" {
		t.Errorf("expected PrivateKey 'super-secret', got %q", pk)
	}

	// Non-existent key
	_, ok = mgr.GetPrivateKey("nonexistent")
	if ok {
		t.Error("GetPrivateKey should return false for non-existent key")
	}
}

func TestDelete(t *testing.T) {
	mgr := newTestKeyManager(t)
	mgr.Load()

	entry := &contracts.SSHKeyEntry{Name: "delete-me"}
	mgr.Set(entry)

	if _, ok := mgr.Get("delete-me"); !ok {
		t.Fatal("key should exist after Set")
	}

	if err := mgr.Delete("delete-me"); err != nil {
		t.Fatalf("Delete failed: %v", err)
	}

	if _, ok := mgr.Get("delete-me"); ok {
		t.Error("key should not exist after Delete")
	}
}

func TestList(t *testing.T) {
	mgr := newTestKeyManager(t)
	mgr.Load()

	mgr.Set(&contracts.SSHKeyEntry{Name: "key1", PrivateKey: "priv1", PublicKey: "pub1"})
	mgr.Set(&contracts.SSHKeyEntry{Name: "key2", PrivateKey: "priv2", PublicKey: "pub2"})

	keys := mgr.List()
	if len(keys) != 2 {
		t.Fatalf("expected 2 keys, got %d", len(keys))
	}

	// Verify no PrivateKey in list results
	for _, k := range keys {
		if k.PrivateKey != "" {
			t.Errorf("List should not expose PrivateKey for key %q", k.Name)
		}
	}
}

func TestResolve(t *testing.T) {
	mgr := newTestKeyManager(t)
	mgr.Load()

	mgr.Set(&contracts.SSHKeyEntry{
		Name:        "resolve-me",
		PrivateKey:  "priv",
		PublicKey:   "ssh-ed25519 AAA",
		Fingerprint: "SHA256:xyz",
		KeyType:     "ed25519",
	})

	fp, kt, pub, ok := mgr.Resolve("resolve-me")
	if !ok {
		t.Fatal("Resolve should return true for existing key")
	}
	if fp != "SHA256:xyz" {
		t.Errorf("expected fingerprint 'SHA256:xyz', got %q", fp)
	}
	if kt != "ed25519" {
		t.Errorf("expected keyType 'ed25519', got %q", kt)
	}
	if pub != "ssh-ed25519 AAA" {
		t.Errorf("expected publicKey 'ssh-ed25519 AAA', got %q", pub)
	}

	// Non-existent
	_, _, _, ok = mgr.Resolve("nonexistent")
	if ok {
		t.Error("Resolve should return false for non-existent key")
	}
}

func TestSaveAndLoadPersistence(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config", "ssh_keys.yaml")

	// First manager: write data
	mgr1 := NewSSHKeyManager(path)
	mgr1.Load()
	mgr1.Set(&contracts.SSHKeyEntry{
		Name:        "persist-me",
		PrivateKey:  "secret",
		PublicKey:   "pub",
		Fingerprint: "fp",
		KeyType:     "ed25519",
	})

	// Second manager: read from same file
	mgr2 := NewSSHKeyManager(path)
	if err := mgr2.Load(); err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	entry, ok := mgr2.Get("persist-me")
	if !ok {
		t.Fatal("key should persist after reload")
	}
	if entry.PublicKey != "pub" {
		t.Errorf("expected PublicKey 'pub', got %q", entry.PublicKey)
	}

	// Verify private key is in the file (YAML persistence)
	pk, ok := mgr2.GetPrivateKey("persist-me")
	if !ok || pk != "secret" {
		t.Errorf("private key should persist in YAML")
	}
}

func TestMigrateFromEndpoints(t *testing.T) {
	mgr := newTestKeyManager(t)
	mgr.Load()

	endpoints := map[string]*contracts.EndpointConfig{
		"myserver": {
			Name: "myserver",
			Connection: &contracts.ConnectionConfig{
				Type:          "ssh",
				Endpoint:      "10.0.0.1:22",
				SSHPrivateKey: "fake-private-key-data",
			},
		},
		"other": {
			Name: "other",
			Connection: &contracts.ConnectionConfig{
				Type:     "unix",
				Endpoint: "/var/run/docker.sock",
				// No SSHPrivateKey — should not be migrated
			},
		},
	}

	migrated, err := mgr.MigrateFromEndpoints(endpoints)
	if err != nil {
		t.Fatalf("MigrateFromEndpoints failed: %v", err)
	}
	if !migrated {
		t.Fatal("expected migration to occur")
	}

	// Verify key was created in store
	entry, ok := mgr.Get("myserver-key")
	if !ok {
		t.Fatal("expected migrated key 'myserver-key' in store")
	}
	if entry.PublicKey != "" {
		t.Log("migrated key has public key metadata")
	}

	// Verify endpoint's SSHPrivateKey was cleared and SSHKeyRef set
	ep := endpoints["myserver"]
	if ep.Connection.SSHPrivateKey != "" {
		t.Error("endpoint SSHPrivateKey should be cleared after migration")
	}
	if ep.Connection.SSHKeyRef != "myserver-key" {
		t.Errorf("expected SSHKeyRef 'myserver-key', got %q", ep.Connection.SSHKeyRef)
	}

	// Verify non-SSH endpoint was not migrated
	if endpoints["other"].Connection.SSHKeyRef != "" {
		t.Error("non-SSH endpoint should not have SSHKeyRef")
	}
}

func TestMigrateFromEndpoints_NoSSHKeys(t *testing.T) {
	mgr := newTestKeyManager(t)
	mgr.Load()

	endpoints := map[string]*contracts.EndpointConfig{
		"local": {
			Name: "local",
			Connection: &contracts.ConnectionConfig{
				Type:     "unix",
				Endpoint: "/var/run/docker.sock",
			},
		},
	}

	migrated, err := mgr.MigrateFromEndpoints(endpoints)
	if err != nil {
		t.Fatalf("MigrateFromEndpoints failed: %v", err)
	}
	if migrated {
		t.Error("expected no migration when no SSH keys present")
	}

	if len(mgr.keys) != 0 {
		t.Error("expected empty key store when no SSH keys to migrate")
	}
}

func TestDelete_NonExistent(t *testing.T) {
	mgr := newTestKeyManager(t)
	mgr.Load()
	if err := mgr.Delete("nonexistent"); err != nil {
		t.Fatalf("Delete on non-existent key should not error: %v", err)
	}
}
