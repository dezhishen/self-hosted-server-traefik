package apprepo

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// FetchIndex fetches and parses a AppIndex from the given URL or file path.
// Supports http://, https://, and file:// schemes.
func FetchIndex(rawURL string) (*contracts.AppIndex, error) {
	data, err := readURL(rawURL)
	if err != nil {
		return nil, fmt.Errorf("fetch index %s: %w", rawURL, err)
	}

	var idx contracts.AppIndex
	if err := yaml.Unmarshal(data, &idx); err != nil {
		return nil, fmt.Errorf("parse index %s: %w", rawURL, err)
	}
	if idx == nil {
		idx = contracts.AppIndex{}
	}
	return &idx, nil
}

// ResolveEntry resolves a template entry against the index's base URL.
//
// Rules:
//   - If the entry is already an absolute URL (http/https), return as-is.
//   - If the entry is a file:// URL, return as-is.
//   - If the entry is a relative path, resolve it against the base URL's directory.
//
// Examples:
//
//	base="https://example.com/templates/index.yaml", entry="services/traefik.yaml"
//	→ "https://example.com/templates/services/traefik.yaml"
//
//	base="file:///home/user/templates/index.yaml", entry="services/traefik.yaml"
//	→ "file:///home/user/templates/services/traefik.yaml"
func ResolveEntry(indexURL, entry string) string {
	// Already absolute
	if strings.HasPrefix(entry, "http://") || strings.HasPrefix(entry, "https://") || strings.HasPrefix(entry, "file://") {
		return entry
	}

	// Relative path — resolve against index URL directory using URL parsing.
	// We MUST use url.Parse then operate only on the Path component, because
	// path.Dir internally calls Clean which collapses "//" to "/" — breaking
	// the scheme separator (https:// → https:/).
	u, err := url.Parse(indexURL)
	if err != nil {
		// Fallback: naive concatenation (unlikely to be correct, but won't crash)
		return strings.TrimRight(indexURL, "/") + "/" + entry
	}
	u.Path = path.Dir(u.Path) + "/" + entry
	return u.String()
}

// DownloadTemplate downloads a template file from a URL and saves it to the given path.
func DownloadTemplate(templateURL, destPath string) error {
	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return fmt.Errorf("create dir for %s: %w", destPath, err)
	}

	data, err := readURL(templateURL)
	if err != nil {
		return fmt.Errorf("download %s: %w", templateURL, err)
	}

	if err := os.WriteFile(destPath, data, 0644); err != nil {
		return fmt.Errorf("write %s: %w", destPath, err)
	}
	return nil
}

// parseIndex parses raw YAML data into a AppIndex.
func parseIndex(data []byte) (*contracts.AppIndex, error) {
	var idx contracts.AppIndex
	if err := yaml.Unmarshal(data, &idx); err != nil {
		return nil, err
	}
	if idx == nil {
		idx = contracts.AppIndex{}
	}
	return &idx, nil
}

// readURL reads content from a URL or file path.
// Supports http://, https://, file://, and raw paths (treated as local file).
func readURL(rawURL string) ([]byte, error) {
	// Local file path
	if !strings.Contains(rawURL, "://") {
		return os.ReadFile(rawURL)
	}

	u, err := url.Parse(rawURL)
	if err != nil {
		return nil, fmt.Errorf("parse URL: %w", err)
	}

	switch u.Scheme {
	case "http", "https":
		resp, err := http.Get(rawURL)
		if err != nil {
			return nil, fmt.Errorf("http get: %w", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("unexpected status %d", resp.StatusCode)
		}
		return io.ReadAll(resp.Body)

	case "file":
		return os.ReadFile(u.Path)

	default:
		return nil, fmt.Errorf("unsupported scheme %q", u.Scheme)
	}
}
