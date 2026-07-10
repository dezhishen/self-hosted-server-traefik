package subscription

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"go.uber.org/zap"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

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

func (m *Manager) Sync(name string) error {
	sub, err := m.Get(name)
	if err != nil {
		return err
	}
	targetDir := filepath.Join(m.dir, name)
	os.MkdirAll(filepath.Dir(targetDir), 0755)

	// Remove existing
	os.RemoveAll(targetDir)

	m.log.Info("cloning subscription", zap.String("name", name), zap.String("url", sub.URL))
	cmd := exec.Command("git", "clone", "--depth=1", sub.URL, targetDir)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("git clone %s: %s: %w", sub.URL, string(out), err)
	}

	m.log.Info("subscription synced", zap.String("name", name))
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
