package service

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"gopkg.in/yaml.v3"
)

// Compile-time check: *Loader implements contracts.ServiceLoader.
var _ contracts.ServiceLoader = (*Loader)(nil)

type Loader struct {
	paths []string
}

func NewLoader(paths []string) *Loader {
	return &Loader{paths: paths}
}

func (l *Loader) LoadAll() ([]*contracts.ServiceDefinition, error) {
	var result []*contracts.ServiceDefinition
	seen := make(map[string]bool)
	for _, dir := range l.paths {
		services, err := l.loadDir(dir, seen)
		if err != nil {
			continue
		}
		result = append(result, services...)
	}
	return result, nil
}

func (l *Loader) Load(name string) (*contracts.ServiceDefinition, error) {
	for _, dir := range l.paths {
		svc, err := l.loadFile(filepath.Join(dir, name+".yaml"))
		if err == nil {
			return svc, nil
		}
		svc, err = l.loadFile(filepath.Join(dir, name+".yml"))
		if err == nil {
			return svc, nil
		}
	}
	return nil, fmt.Errorf("service %q not found", name)
}

func (l *Loader) Discover(paths []string) ([]*contracts.ServiceDefinition, error) {
	return l.LoadAll()
}

// AddPath adds a directory path to the loader's search paths at runtime.
// Used to register subscription template directories after they are synced.
func (l *Loader) AddPath(path string) {
	l.paths = append(l.paths, path)
}

func (l *Loader) loadDir(dir string, seen map[string]bool) ([]*contracts.ServiceDefinition, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var result []*contracts.ServiceDefinition
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if !strings.HasSuffix(name, ".yaml") && !strings.HasSuffix(name, ".yml") {
			continue
		}
		if strings.HasPrefix(name, "_") {
			continue
		}
		svc, err := l.loadFile(filepath.Join(dir, name))
		if err != nil {
			continue
		}
		if seen[svc.Name] {
			continue
		}
		seen[svc.Name] = true
		result = append(result, svc)
	}
	return result, nil
}

func (l *Loader) loadFile(path string) (*contracts.ServiceDefinition, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var svc contracts.ServiceDefinition
	if err := yaml.Unmarshal(data, &svc); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	if svc.Name == "" {
		return nil, fmt.Errorf("service %s has no name", path)
	}
	return &svc, nil
}
