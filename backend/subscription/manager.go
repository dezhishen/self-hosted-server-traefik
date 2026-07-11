package subscription

import (
	"archive/zip"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

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
// Users can remove or modify them after initial setup.
var DefaultSubscriptions = []*contracts.Subscription{
	{
		Name:        "community",
		Description: "Community service templates from the SelfHosted project",
		URL:         "https://github.com/dezhishen/self-hosted-server-traefik.git",
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
		return nil // already has subscriptions, skip
	}
	for _, sub := range DefaultSubscriptions {
		if err := m.store.Save([]*contracts.Subscription{sub}); err != nil {
			return err
		}
		m.log.Info("seeded default subscription", zap.String("name", sub.Name), zap.String("url", sub.URL))
	}
	return nil
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

	// Prefer HTTP tarball download for GitHub URLs (no git dependency needed)
	if owner, repo, ok := parseGitHubURL(sub.URL); ok {
		m.log.Info("downloading subscription tarball", zap.String("name", name), zap.String("url", sub.URL))
		if err := m.downloadGitHubTarball(owner, repo, targetDir); err != nil {
			return fmt.Errorf("download tarball %s: %w", sub.URL, err)
		}
		m.log.Info("subscription synced", zap.String("name", name))
		return nil
	}

	// Fallback: git clone for non-GitHub URLs
	m.log.Info("cloning subscription via git", zap.String("name", name), zap.String("url", sub.URL))
	cmd := exec.Command("git", "clone", "--depth=1", sub.URL, targetDir)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("git clone %s: %s: %w", sub.URL, string(out), err)
	}

	m.log.Info("subscription synced", zap.String("name", name))
	return nil
}

// downloadGitHubTarball downloads a GitHub repository as a zipball and extracts it.
func (m *Manager) downloadGitHubTarball(owner, repo, targetDir string) error {
	// Use GitHub's zipball API (returns a zip of the default branch)
	zipURL := fmt.Sprintf("https://api.github.com/repos/%s/%s/zipball", owner, repo)

	req, err := http.NewRequest("GET", zipURL, nil)
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	// User-Agent is required by GitHub API
	req.Header.Set("User-Agent", "selfhosted-server-traefik/1.0")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	// Download to temp file
	tmpFile, err := os.CreateTemp("", "sub-*.zip")
	if err != nil {
		return fmt.Errorf("create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := io.Copy(tmpFile, resp.Body); err != nil {
		tmpFile.Close()
		return fmt.Errorf("download: %w", err)
	}
	tmpFile.Close()

	// Extract zip archive
	if err := m.extractZip(tmpFile.Name(), targetDir); err != nil {
		return fmt.Errorf("extract: %w", err)
	}

	return nil
}

// extractZip extracts a zip archive to the target directory.
// GitHub zipballs contain a single root directory named {owner}-{repo}-{sha};
// we strip that and extract contents directly into targetDir.
func (m *Manager) extractZip(zipPath, targetDir string) error {
	r, err := zip.OpenReader(zipPath)
	if err != nil {
		return fmt.Errorf("open zip: %w", err)
	}
	defer r.Close()

	// Find the root directory prefix to strip
	var rootPrefix string
	for _, f := range r.File {
		if f.FileInfo().IsDir() {
			parts := strings.SplitN(f.Name, "/", 2)
			if len(parts) == 2 && parts[1] == "" {
				rootPrefix = parts[0] + "/"
				break
			}
		}
	}

	for _, f := range r.File {
		// Skip the root directory entry itself
		if f.Name == rootPrefix {
			continue
		}

		// Strip root prefix to get relative path
		relPath := f.Name
		if rootPrefix != "" && strings.HasPrefix(relPath, rootPrefix) {
			relPath = strings.TrimPrefix(relPath, rootPrefix)
		}
		if relPath == "" {
			continue
		}

		outPath := filepath.Join(targetDir, relPath)

		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(outPath, 0755); err != nil {
				return fmt.Errorf("create dir %s: %w", outPath, err)
			}
			continue
		}

		// Ensure parent directory exists
		if err := os.MkdirAll(filepath.Dir(outPath), 0755); err != nil {
			return fmt.Errorf("create parent dir for %s: %w", outPath, err)
		}

		// Extract file
		src, err := f.Open()
		if err != nil {
			return fmt.Errorf("open zip entry %s: %w", f.Name, err)
		}

		dst, err := os.OpenFile(outPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
		if err != nil {
			src.Close()
			return fmt.Errorf("create file %s: %w", outPath, err)
		}

		if _, err := io.Copy(dst, src); err != nil {
			src.Close()
			dst.Close()
			return fmt.Errorf("write file %s: %w", outPath, err)
		}
		src.Close()
		dst.Close()
	}

	return nil
}

// parseGitHubURL checks if a URL is a GitHub repository URL and extracts owner/repo.
// Supports formats:
//   - https://github.com/owner/repo.git
//   - https://github.com/owner/repo
//   - git@github.com:owner/repo.git
func parseGitHubURL(rawURL string) (owner, repo string, ok bool) {
	// Handle git@github.com:owner/repo.git format
	if strings.HasPrefix(rawURL, "git@github.com:") {
		path := strings.TrimPrefix(rawURL, "git@github.com:")
		path = strings.TrimSuffix(path, ".git")
		parts := strings.SplitN(path, "/", 2)
		if len(parts) == 2 && parts[0] != "" && parts[1] != "" {
			return parts[0], parts[1], true
		}
		return "", "", false
	}

	// Handle https://github.com/owner/repo[.git] format
	u, err := url.Parse(rawURL)
	if err != nil {
		return "", "", false
	}
	if u.Host != "github.com" {
		return "", "", false
	}
	path := strings.TrimSuffix(u.Path, ".git")
	path = strings.Trim(path, "/")
	parts := strings.SplitN(path, "/", 2)
	if len(parts) == 2 && parts[0] != "" && parts[1] != "" {
		return parts[0], parts[1], true
	}
	return "", "", false
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
