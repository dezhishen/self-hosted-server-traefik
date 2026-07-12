package contracts

import "time"

// SSHKeyEntry represents a single SSH key stored in the key store.
// PrivateKey is never exposed via JSON.
type SSHKeyEntry struct {
	Name        string `yaml:"name" json:"name"`
	PrivateKey  string `yaml:"private_key" json:"-"`                    // never exposed via JSON
	PublicKey   string `yaml:"public_key" json:"public_key"`           // computed, read-only
	Fingerprint string `yaml:"fingerprint" json:"fingerprint"`         // computed, read-only
	KeyType     string `yaml:"key_type" json:"key_type"`               // computed, read-only
	CreatedAt   string `yaml:"created_at" json:"created_at"`
	Comment     string `yaml:"comment,omitempty" json:"comment,omitempty"`
}

// SSHKeyStore is the on-disk format for the keys file.
type SSHKeyStore struct {
	Keys map[string]*SSHKeyEntry `yaml:"keys" json:"keys"`
}

// NewSSHKeyEntry creates a new SSHKeyEntry with the current timestamp.
func NewSSHKeyEntry(name, privateKey, publicKey, fingerprint, keyType, comment string) *SSHKeyEntry {
	return &SSHKeyEntry{
		Name:        name,
		PrivateKey:  privateKey,
		PublicKey:   publicKey,
		Fingerprint: fingerprint,
		KeyType:     keyType,
		CreatedAt:   time.Now().UTC().Format(time.RFC3339),
		Comment:     comment,
	}
}
