package subscription

import (
	"fmt"
	"os"
	"path/filepath"

	"go.uber.org/zap"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// Compile-time check: *Manager implements contracts.SubscriptionManager.
var _ contracts.SubscriptionManager = (*Manager)(nil)

type Manager struct {
	store contracts.SubscriptionStore
	dir   string
	log   *zap.Logger
}

func NewManager(store contracts.SubscriptionStore, baseDir string, log *zap.Logger) *Manager {
	return &Manager{
		store: store,
		dir:   filepath.Join(baseDir, "templates"),
		log:   log,
	}
}

func (m *Manager) Add(sub *contracts.Subscription) error {
	subs, err := m.store.Load()
	if err != nil {
		return err
	}
	for _, s := range subs {
		if s.Name == sub.Name {
			return fmt.Errorf("subscription %q already exists", sub.Name)
		}
	}
	subs = append(subs, sub)
	if err := m.store.Save(subs); err != nil {
		return err
	}
	return m.Sync(sub.Name)
}

func (m *Manager) Remove(name string) error {
	subs, err := m.store.Load()
	if err != nil {
		return err
	}
	var updated []*contracts.Subscription
	for _, s := range subs {
		if s.Name != name {
			updated = append(updated, s)
		}
	}
	if err := m.store.Save(updated); err != nil {
		return err
	}
	// Clean up local directory
	localPath := filepath.Join(m.dir, name)
	os.RemoveAll(localPath)
	return nil
}

func (m *Manager) List() ([]*contracts.Subscription, error) {
	return m.store.Load()
}

func (m *Manager) Get(name string) (*contracts.Subscription, error) {
	subs, err := m.store.Load()
	if err != nil {
		return nil, err
	}
	for _, s := range subs {
		if s.Name == name {
			return s, nil
		}
	}
	return nil, fmt.Errorf("subscription %q not found", name)
}

// DefaultSubscriptions returns the default subscriptions to seed on first run.
// The "community" subscription now points to the project's index.yaml on GitHub.
var DefaultSubscriptions = []*contracts.Subscription{
	{
		Name:        "community",
		Description: "Community service templates from the SelfHosted project",
		URL:         "https://raw.githubusercontent.com/dezhishen/self-hosted-server-traefik/main/templates/index.yaml",
		Enabled:     true,
	},
}

// SeedDefaults adds default subscriptions if the store is empty.
func (m *Manager) SeedDefaults() error {
	subs, err := m.store.Load()
	if err != nil {
		return err
	}
	if len(subs) > 0 {
		return nil
	}
	if err := m.store.Save(DefaultSubscriptions); err != nil {
		return err
	}
	m.log.Info("seeded default subscriptions", zap.Int("count", len(DefaultSubscriptions)))
	return nil
}

// Sync fetches the subscription's index.yaml and downloads all listed templates.
func (m *Manager) Sync(name string) error {
	sub, err := m.Get(name)
	if err != nil {
		return err
	}

	m.log.Info("syncing subscription", zap.String("name", name), zap.String("url", sub.URL))

	// 1. Fetch raw index.yaml content
	rawData, err := readURL(sub.URL)
	if err != nil {
		return fmt.Errorf("fetch index for %s: %w", name, err)
	}

	// 2. Parse into TemplateIndex
	idx, err := parseIndex(rawData)
	if err != nil {
		return fmt.Errorf("parse index for %s: %w", name, err)
	}

	m.log.Info("index fetched", zap.String("name", name), zap.Int("templates", len(*idx)))

	// 3. Create target directory
	targetDir := filepath.Join(m.dir, name)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("create target dir %s: %w", targetDir, err)
	}

	// 4. Cache the raw index.yaml
	cachePath := filepath.Join(targetDir, "index.yaml")
	if err := os.WriteFile(cachePath, rawData, 0644); err != nil {
		m.log.Warn("failed to cache index", zap.String("name", name), zap.Error(err))
	}

	// 5. Download each template
	var failed int
	for _, entry := range *idx {
		templateURL := ResolveEntry(sub.URL, entry)
		destPath := filepath.Join(targetDir, entry)

		m.log.Debug("downloading template",
			zap.String("name", name),
			zap.String("url", templateURL),
			zap.String("dest", destPath),
		)

		if err := DownloadTemplate(templateURL, destPath); err != nil {
			m.log.Warn("failed to download template",
				zap.String("name", name),
				zap.String("template", entry),
				zap.Error(err),
			)
			failed++
		}
	}

	if failed > 0 {
		m.log.Warn("subscription sync completed with errors",
			zap.String("name", name),
			zap.Int("failed", failed),
			zap.Int("total", len(*idx)),
		)
		return fmt.Errorf("synced %s: %d/%d templates failed", name, failed, len(*idx))
	}

	m.log.Info("subscription synced", zap.String("name", name), zap.Int("templates", len(*idx)))
	return nil
}

func (m *Manager) SyncAll() error {
	subs, err := m.store.Load()
	if err != nil {
		return err
	}
	for _, sub := range subs {
		if sub.Enabled {
			if err := m.Sync(sub.Name); err != nil {
				m.log.Error("sync subscription", zap.String("name", sub.Name), zap.Error(err))
			}
		}
	}
	return nil
}

func (m *Manager) GetLocalPath(name string) (string, error) {
	p := filepath.Join(m.dir, name)
	if _, err := os.Stat(p); err != nil {
		return "", fmt.Errorf("subscription %q not synced locally", name)
	}
	return p, nil
}
