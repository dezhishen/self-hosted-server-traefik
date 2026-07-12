package contracts

import (
	"encoding/json"
	"testing"

	"gopkg.in/yaml.v3"
)

func TestSSHKeyEntry_YAML(t *testing.T) {
	entry := &SSHKeyEntry{
		Name:        "test-key",
		PrivateKey:  "private-pem-data",
		PublicKey:   "ssh-ed25519 AAA...",
		Fingerprint: "SHA256:abc...",
		KeyType:     "ed25519",
		CreatedAt:   "2026-07-12T10:00:00Z",
		Comment:     "my key",
	}

	data, err := yaml.Marshal(entry)
	if err != nil {
		t.Fatalf("failed to marshal YAML: %v", err)
	}

	var decoded SSHKeyEntry
	if err := yaml.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("failed to unmarshal YAML: %v", err)
	}

	if decoded.Name != entry.Name {
		t.Errorf("expected Name %q, got %q", entry.Name, decoded.Name)
	}
	if decoded.PrivateKey != entry.PrivateKey {
		t.Errorf("expected PrivateKey to be preserved in YAML")
	}
	if decoded.PublicKey != entry.PublicKey {
		t.Errorf("expected PublicKey %q, got %q", entry.PublicKey, decoded.PublicKey)
	}
	if decoded.Fingerprint != entry.Fingerprint {
		t.Errorf("expected Fingerprint %q, got %q", entry.Fingerprint, decoded.Fingerprint)
	}
	if decoded.KeyType != entry.KeyType {
		t.Errorf("expected KeyType %q, got %q", entry.KeyType, decoded.KeyType)
	}
}

func TestSSHKeyEntry_JSON(t *testing.T) {
	entry := &SSHKeyEntry{
		Name:        "test-key",
		PrivateKey:  "private-pem-data",
		PublicKey:   "ssh-ed25519 AAA...",
		Fingerprint: "SHA256:abc...",
		KeyType:     "ed25519",
		CreatedAt:   "2026-07-12T10:00:00Z",
	}

	data, err := json.Marshal(entry)
	if err != nil {
		t.Fatalf("failed to marshal JSON: %v", err)
	}

	var decoded SSHKeyEntry
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("failed to unmarshal JSON: %v", err)
	}

	// PrivateKey should NOT appear in JSON output
	if decoded.PrivateKey != "" {
		t.Error("PrivateKey should be omitted from JSON (json:\"-\")")
	}

	// Verify the raw JSON doesn't contain private_key
	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("failed to decode raw JSON: %v", err)
	}
	if _, exists := raw["private_key"]; exists {
		t.Error("private_key should NOT exist in JSON output")
	}

	// Other fields should be present
	if decoded.Name != entry.Name {
		t.Errorf("expected Name %q, got %q", entry.Name, decoded.Name)
	}
	if decoded.PublicKey != entry.PublicKey {
		t.Errorf("expected PublicKey %q, got %q", entry.PublicKey, decoded.PublicKey)
	}
	if decoded.Fingerprint != entry.Fingerprint {
		t.Errorf("expected Fingerprint %q, got %q", entry.Fingerprint, decoded.Fingerprint)
	}
}

func TestSSHKeyStore_RoundTrip(t *testing.T) {
	store := &SSHKeyStore{
		Keys: map[string]*SSHKeyEntry{
			"key1": {
				Name:        "key1",
				PrivateKey:  "priv1",
				PublicKey:   "pub1",
				Fingerprint: "fp1",
				KeyType:     "ed25519",
			},
			"key2": {
				Name:        "key2",
				PrivateKey:  "priv2",
				PublicKey:   "pub2",
				Fingerprint: "fp2",
				KeyType:     "rsa",
			},
		},
	}

	data, err := yaml.Marshal(store)
	if err != nil {
		t.Fatalf("failed to marshal YAML: %v", err)
	}

	var decoded SSHKeyStore
	if err := yaml.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("failed to unmarshal YAML: %v", err)
	}

	if len(decoded.Keys) != 2 {
		t.Fatalf("expected 2 keys, got %d", len(decoded.Keys))
	}

	if decoded.Keys["key1"].PrivateKey != "priv1" {
		t.Error("key1 PrivateKey should be preserved in YAML")
	}
	if decoded.Keys["key2"].PrivateKey != "priv2" {
		t.Error("key2 PrivateKey should be preserved in YAML")
	}
}

func TestNewSSHKeyEntry(t *testing.T) {
	entry := NewSSHKeyEntry("mykey", "priv", "pub", "fp", "ed25519", "test")
	if entry.Name != "mykey" {
		t.Errorf("expected Name 'mykey', got %q", entry.Name)
	}
	if entry.PrivateKey != "priv" {
		t.Errorf("expected PrivateKey 'priv', got %q", entry.PrivateKey)
	}
	if entry.PublicKey != "pub" {
		t.Errorf("expected PublicKey 'pub', got %q", entry.PublicKey)
	}
	if entry.Fingerprint != "fp" {
		t.Errorf("expected Fingerprint 'fp', got %q", entry.Fingerprint)
	}
	if entry.KeyType != "ed25519" {
		t.Errorf("expected KeyType 'ed25519', got %q", entry.KeyType)
	}
	if entry.CreatedAt == "" {
		t.Error("CreatedAt should not be empty")
	}
	if entry.Comment != "test" {
		t.Errorf("expected Comment 'test', got %q", entry.Comment)
	}
}
