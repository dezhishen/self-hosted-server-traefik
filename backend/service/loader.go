package service

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
	"gopkg.in/yaml.v3"
)

// Compile-time check: *Loader implements contracts.ServiceLoader.
var _ contracts.ServiceLoader = (*Loader)(nil)

type Loader struct {
	paths  []string
	logger logger.Logger
}

func NewLoader(paths []string, log logger.Logger) *Loader {
	return &Loader{paths: paths, logger: log}
}

// deriveSource returns a human-readable source label for a template directory.
// This is used to tag service definitions with their origin and to enable
// per-source deduplication so that templates from different sources (built-in,
// subscriptions, generated) all appear in the service list.
func deriveSource(dir string) string {
	base := filepath.Base(dir)
	// Map well-known directory names to readable source labels.
	switch base {
	case "apps":
		return "builtin"
	case "generated":
		return "generated"
	default:
		// For subscription directories like "community", "test", etc.
		return base
	}
}

func (l *Loader) LoadAll() ([]*contracts.ServiceDefinition, error) {
	var result []*contracts.ServiceDefinition
	// Dedup key is "source:name" so templates from different sources
	// (built-in, subscriptions, generated) are all visible.
	seen := make(map[string]bool)
	for _, dir := range l.paths {
		l.logger.Debug("loading dir", logger.String("dir", dir))
		services, err := l.loadDir(dir, seen)
		if err != nil {
			l.logger.Debug("skipping dir", logger.String("dir", dir), logger.Error(err))
			continue
		}
		l.logger.Debug("loaded dir", logger.String("dir", dir), logger.Int("count", len(services)))
		result = append(result, services...)
	}
	l.logger.Debug("total services loaded", logger.Int("count", len(result)))
	return result, nil
}

func (l *Loader) Load(name string) (*contracts.ServiceDefinition, error) {
	for _, dir := range l.paths {
		// Try direct lookup first (for flat directories)
		svc, err := l.loadFile(filepath.Join(dir, name+".yaml"))
		if err == nil {
			return svc, nil
		}
		svc, err = l.loadFile(filepath.Join(dir, name+".yml"))
		if err == nil {
			return svc, nil
		}

		// If the directory has an index.yaml, search its entries for the service.
		// This handles nested layouts like apps/services/{name}.yaml.
		idx, err := loadLocalIndex(filepath.Join(dir, "index.yaml"))
		if err != nil {
			continue
		}
		for _, entry := range *idx {
			stem := strings.TrimSuffix(entry, ".yaml")
			stem = strings.TrimSuffix(stem, ".yml")
			if filepath.Base(stem) == name {
				svc, err := l.loadFile(filepath.Join(dir, entry))
				if err == nil {
					return svc, nil
				}
			}
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

// loadDir loads templates from a directory, preferring index.yaml if present.
// Falls back to directory scan (*.yaml) if no index.yaml exists.
func (l *Loader) loadDir(dir string, seen map[string]bool) ([]*contracts.ServiceDefinition, error) {
	// Prefer index.yaml
	indexPath := filepath.Join(dir, "index.yaml")
	if _, err := os.Stat(indexPath); err == nil {
		return l.loadIndex(indexPath, dir, seen)
	}

	// Fallback: directory scan
	return l.scanDir(dir, seen)
}

// loadIndex reads an index.yaml and loads all listed template files.
// Templates are tagged with their source (derived from baseDir) and deduped
// by "source:name" so templates from different sources all appear.
func (l *Loader) loadIndex(indexPath, baseDir string, seen map[string]bool) ([]*contracts.ServiceDefinition, error) {
	idx, err := loadLocalIndex(indexPath)
	if err != nil {
		l.logger.Debug("loading index", logger.String("path", indexPath), logger.Error(err))
		return nil, err
	}
	l.logger.Debug("index loaded", logger.String("path", indexPath), logger.Int("entries", len(*idx)))

	source := deriveSource(baseDir)
	var result []*contracts.ServiceDefinition
	for _, entry := range *idx {
		svcPath := filepath.Join(baseDir, entry)
		svc, err := l.loadFile(svcPath)
		if err != nil {
			l.logger.Debug("skipping service file", logger.String("path", svcPath), logger.Error(err))
			continue
		}
		key := source + ":" + svc.Name
		if seen[key] {
			continue
		}
		seen[key] = true
		svc.Source = source
		result = append(result, svc)
	}
	l.logger.Debug("services loaded from index", logger.String("source", source), logger.Int("count", len(result)))
	return result, nil
}

// scanDir loads all *.yaml/*.yml files from a directory (fallback when no index.yaml).
// Templates are tagged with their source and deduped by "source:name".
func (l *Loader) scanDir(dir string, seen map[string]bool) ([]*contracts.ServiceDefinition, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	source := deriveSource(dir)
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
		key := source + ":" + svc.Name
		if seen[key] {
			continue
		}
		seen[key] = true
		svc.Source = source
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

// loadLocalIndex reads and parses a local index.yaml file.
func loadLocalIndex(path string) (*contracts.AppIndex, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var idx contracts.AppIndex
	if err := yaml.Unmarshal(data, &idx); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	if idx == nil {
		idx = contracts.AppIndex{}
	}
	return &idx, nil
}
