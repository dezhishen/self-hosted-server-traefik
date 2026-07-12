package server

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
)

// apiKeyEntry represents a single API key with its scope.
type apiKeyEntry struct {
	Key         string    `json:"key"`
	Scope       string    `json:"scope"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at"`
}

// apiKeyManager persists API keys to a JSON file and validates them in-memory.
type apiKeyManager struct {
	mu       sync.RWMutex
	filePath string
	keys     map[string]*apiKeyEntry // key hash -> entry
	l        logger.Logger
}

func newAPIKeyManager(configDir string, l logger.Logger) *apiKeyManager {
	m := &apiKeyManager{
		filePath: filepath.Join(configDir, "apikeys.json"),
		keys:     make(map[string]*apiKeyEntry),
		l:        l,
	}
	m.load()
	return m
}

func (m *apiKeyManager) load() {
	data, err := os.ReadFile(m.filePath)
	if err != nil {
		if !os.IsNotExist(err) {
			m.l.Warn("failed to read apikeys.json", logger.Error(err))
		}
		return
	}
	var entries []*apiKeyEntry
	if err := json.Unmarshal(data, &entries); err != nil {
		m.l.Warn("failed to parse apikeys.json", logger.Error(err))
		return
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.keys = make(map[string]*apiKeyEntry, len(entries))
	for _, e := range entries {
		m.keys[e.Key] = e
	}
}

func (m *apiKeyManager) save() error {
	m.mu.RLock()
	entries := make([]*apiKeyEntry, 0, len(m.keys))
	for _, e := range m.keys {
		entries = append(entries, e)
	}
	m.mu.RUnlock()

	data, err := json.MarshalIndent(entries, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal apikeys: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(m.filePath), 0755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}
	if err := os.WriteFile(m.filePath, data, 0644); err != nil {
		return fmt.Errorf("write apikeys.json: %w", err)
	}
	return nil
}

func generateAPIKey() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

// Create generates a new API key with the given scope and description.
func (m *apiKeyManager) Create(scope, description string) (*apiKeyEntry, error) {
	raw, err := generateAPIKey()
	if err != nil {
		return nil, fmt.Errorf("generate key: %w", err)
	}
	entry := &apiKeyEntry{
		Key:         raw,
		Scope:       scope,
		Description: description,
		CreatedAt:   time.Now(),
	}

	m.mu.Lock()
	m.keys[raw] = entry
	m.mu.Unlock()

	if err := m.save(); err != nil {
		// Rollback in-memory state on save failure
		m.mu.Lock()
		delete(m.keys, raw)
		m.mu.Unlock()
		return nil, err
	}
	return entry, nil
}

// Validate checks if the given key exists and returns its scope.
func (m *apiKeyManager) Validate(key string) (string, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	entry, ok := m.keys[key]
	if !ok {
		return "", false
	}
	return entry.Scope, true
}

// List returns all stored API keys.
func (m *apiKeyManager) List() []*apiKeyEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make([]*apiKeyEntry, 0, len(m.keys))
	for _, e := range m.keys {
		result = append(result, e)
	}
	return result
}

// Revoke removes an API key by its value.
func (m *apiKeyManager) Revoke(key string) bool {
	m.mu.Lock()
	_, ok := m.keys[key]
	if !ok {
		m.mu.Unlock()
		return false
	}
	delete(m.keys, key)
	m.mu.Unlock()

	if err := m.save(); err != nil {
		m.l.Warn("failed to save after revoke", logger.Error(err))
	}
	return true
}
