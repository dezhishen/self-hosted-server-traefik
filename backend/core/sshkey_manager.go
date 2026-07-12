package core

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"

	gossh "golang.org/x/crypto/ssh"
	"gopkg.in/yaml.v3"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// SSHKeyManager manages the ssh_keys.yaml file.
// Thread-safe: all public methods acquire the appropriate lock.
type SSHKeyManager struct {
	path string
	mu   sync.RWMutex
	keys map[string]*contracts.SSHKeyEntry
}

// NewSSHKeyManager creates a new SSHKeyManager with the given file path.
// Does not load the file — call Load() separately.
func NewSSHKeyManager(path string) *SSHKeyManager {
	return &SSHKeyManager{
		path: path,
		keys: make(map[string]*contracts.SSHKeyEntry),
	}
}

// Load reads the ssh_keys.yaml file. If the file does not exist, initializes
// an empty key store (no error).
func (m *SSHKeyManager) Load() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	data, err := os.ReadFile(m.path)
	if err != nil {
		if os.IsNotExist(err) {
			m.keys = make(map[string]*contracts.SSHKeyEntry)
			return nil
		}
		return fmt.Errorf("read ssh_keys.yaml: %w", err)
	}

	var store contracts.SSHKeyStore
	if err := yaml.Unmarshal(data, &store); err != nil {
		return fmt.Errorf("parse ssh_keys.yaml: %w", err)
	}
	if store.Keys == nil {
		m.keys = make(map[string]*contracts.SSHKeyEntry)
	} else {
		m.keys = store.Keys
	}
	return nil
}

// Save writes the in-memory key store to ssh_keys.yaml.
// Creates the config directory if it does not exist.
func (m *SSHKeyManager) Save() error {
	dir := filepath.Dir(m.path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}

	store := &contracts.SSHKeyStore{Keys: m.keys}
	data, err := yaml.Marshal(store)
	if err != nil {
		return fmt.Errorf("marshal ssh_keys.yaml: %w", err)
	}
	if err := os.WriteFile(m.path, data, 0644); err != nil {
		return fmt.Errorf("write ssh_keys.yaml: %w", err)
	}
	return nil
}

// Get returns a copy (without PrivateKey) of the SSHKeyEntry for the given name.
// Returns false if the key does not exist.
func (m *SSHKeyManager) Get(name string) (*contracts.SSHKeyEntry, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	entry, ok := m.keys[name]
	if !ok {
		return nil, false
	}
	// Return a copy without PrivateKey for safety
	copy := *entry
	copy.PrivateKey = ""
	return &copy, true
}

// GetPrivateKey returns only the private key for the given key name.
// This is used at runtime to populate ConnectionConfig.SSHPrivateKey.
func (m *SSHKeyManager) GetPrivateKey(name string) (string, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	entry, ok := m.keys[name]
	if !ok {
		return "", false
	}
	return entry.PrivateKey, true
}

// Set upserts a key entry and saves to disk.
func (m *SSHKeyManager) Set(entry *contracts.SSHKeyEntry) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.keys[entry.Name] = entry
	return m.saveLocked()
}

// Delete removes a key entry and saves to disk.
func (m *SSHKeyManager) Delete(name string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	delete(m.keys, name)
	return m.saveLocked()
}

// List returns all key entries (without PrivateKey).
func (m *SSHKeyManager) List() []*contracts.SSHKeyEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()

	result := make([]*contracts.SSHKeyEntry, 0, len(m.keys))
	for _, entry := range m.keys {
		copy := *entry
		copy.PrivateKey = ""
		result = append(result, &copy)
	}
	return result
}

// Resolve returns the metadata fields for a given key reference.
// Returns (fingerprint, keyType, publicKey, ok).
func (m *SSHKeyManager) Resolve(keyRef string) (fingerprint, keyType, publicKey string, ok bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	entry, found := m.keys[keyRef]
	if !found {
		return "", "", "", false
	}
	return entry.Fingerprint, entry.KeyType, entry.PublicKey, true
}

// saveLocked saves the key store to disk, assuming the write lock is already held.
func (m *SSHKeyManager) saveLocked() error {
	dir := filepath.Dir(m.path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}

	store := &contracts.SSHKeyStore{Keys: m.keys}
	data, err := yaml.Marshal(store)
	if err != nil {
		return fmt.Errorf("marshal ssh_keys.yaml: %w", err)
	}
	if err := os.WriteFile(m.path, data, 0644); err != nil {
		return fmt.Errorf("write ssh_keys.yaml: %w", err)
	}
	return nil
}

// MigrateFromEndpoints scans all endpoints for legacy SSHPrivateKey values.
// If found, it extracts the key into the key store with an auto-generated name,
// sets SSHKeyRef, and clears SSHPrivateKey.
// Returns true if any migration occurred.
func (m *SSHKeyManager) MigrateFromEndpoints(endpoints map[string]*contracts.EndpointConfig) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	migrated := false
	for epName, ep := range endpoints {
		if ep.Connection == nil || ep.Connection.SSHPrivateKey == "" {
			continue
		}

		// Auto-generate key name from endpoint name
		keyName := epName + "-key"

		// Avoid name collision: try keyName, then keyName-1, keyName-2, ...
		// (check both in-memory and on the key itself)
		finalName := keyName
		for counter := 1; ; counter++ {
			if _, exists := m.keys[finalName]; !exists {
				break
			}
			if counter == 1 {
				finalName = fmt.Sprintf("%s-%d", keyName, counter)
			} else {
				finalName = fmt.Sprintf("%s-%d", keyName[:len(keyName)-len(fmt.Sprintf("-%d", counter-1))], counter)
			}
		}

		// Extract metadata from private key using existing helpers (moved to contracts package)
		publicKey, fingerprint, keyType := extractSSHKeyMeta(ep.Connection.SSHPrivateKey)

		entry := &contracts.SSHKeyEntry{
			Name:        finalName,
			PrivateKey:  ep.Connection.SSHPrivateKey,
			PublicKey:   publicKey,
			Fingerprint: fingerprint,
			KeyType:     keyType,
		}

		m.keys[finalName] = entry
		ep.Connection.SSHKeyRef = finalName
		ep.Connection.SSHPrivateKey = "" // clear legacy field
		migrated = true
	}

	return migrated, nil
}

// extractSSHKeyMeta extracts public key, fingerprint, and key type from a PEM-encoded private key.
// This is a thin wrapper that mirrors the logic from the old computeSSHKeyMeta (now in ssh.go).
// It returns empty strings if parsing fails.
func extractSSHKeyMeta(pemData string) (publicKey, fingerprint, keyType string) {
	if pemData == "" {
		return "", "", ""
	}

	signer, err := gossh.ParsePrivateKey([]byte(pemData))
	if err != nil {
		return "", "", ""
	}

	pub := signer.PublicKey()
	publicKey = string(gossh.MarshalAuthorizedKey(pub))
	fingerprint = gossh.FingerprintSHA256(pub)

	switch pub.Type() {
	case gossh.KeyAlgoED25519:
		keyType = "ed25519"
	case gossh.KeyAlgoRSA:
		keyType = "rsa"
	case gossh.KeyAlgoECDSA256, gossh.KeyAlgoECDSA384, gossh.KeyAlgoECDSA521:
		keyType = "ecdsa"
	default:
		keyType = pub.Type()
	}

	return
}
