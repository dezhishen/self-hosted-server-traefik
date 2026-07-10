package store

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

type ArgsStore struct {
	mu       sync.RWMutex
	basePath string
}

func NewArgsStore(basePath string) *ArgsStore {
	return &ArgsStore{basePath: basePath}
}

func (s *ArgsStore) Get(name string) (*contracts.ParamValue, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	data, err := os.ReadFile(s.filePath(name))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("param %q not found", name)
		}
		return nil, err
	}
	var pv contracts.ParamValue
	if err := json.Unmarshal(data, &pv); err != nil {
		return nil, err
	}
	return &pv, nil
}

func (s *ArgsStore) Set(value *contracts.ParamValue) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := os.MkdirAll(s.basePath, 0755); err != nil {
		return err
	}
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return os.WriteFile(s.filePath(value.Name), data, 0644)
}

func (s *ArgsStore) GetAll() ([]*contracts.ParamValue, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	entries, err := os.ReadDir(s.basePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var result []*contracts.ParamValue
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		data, err := os.ReadFile(filepath.Join(s.basePath, e.Name()))
		if err != nil {
			continue
		}
		var pv contracts.ParamValue
		if err := json.Unmarshal(data, &pv); err != nil {
			continue
		}
		result = append(result, &pv)
	}
	return result, nil
}

func (s *ArgsStore) Delete(name string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return os.Remove(s.filePath(name))
}

func (s *ArgsStore) Has(name string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, err := os.Stat(s.filePath(name))
	if os.IsNotExist(err) {
		return false, nil
	}
	return err == nil, err
}

func (s *ArgsStore) ListDefs() ([]*contracts.ParamDef, error) {
	return nil, fmt.Errorf("not implemented")
}

func (s *ArgsStore) Watch(names []string) (<-chan struct{}, error) {
	return nil, fmt.Errorf("not implemented")
}

func (s *ArgsStore) filePath(name string) string {
	return filepath.Join(s.basePath, name+".json")
}
