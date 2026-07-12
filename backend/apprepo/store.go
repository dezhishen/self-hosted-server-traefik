package apprepo

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time check: *FileStore implements contracts.AppRepoStore.
var _ contracts.AppRepoStore = (*FileStore)(nil)

type FileStore struct {
	mu   sync.RWMutex
	path string
}

func NewFileStore(path string) *FileStore {
	return &FileStore{path: path}
}

func (s *FileStore) Load() ([]*contracts.AppRepo, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	data, err := os.ReadFile(s.path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var subs []*contracts.AppRepo
	if err := json.Unmarshal(data, &subs); err != nil {
		return nil, err
	}
	if subs == nil {
		subs = []*contracts.AppRepo{}
	}
	return subs, nil
}

func (s *FileStore) Save(subscriptions []*contracts.AppRepo) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := os.MkdirAll(filepath.Dir(s.path), 0755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(subscriptions, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, data, 0644)
}
