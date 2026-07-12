package contracts

// AppIndex is a flat list of app definition addresses.
//
// Each entry is a relative path or absolute URL pointing to an app YAML file.
// Relative paths are resolved relative to the index.yaml's own location.
//
// Examples:
//   - "services/traefik.yaml" − relative path (resolved against index location)
//   - "https://example.com/apps/traefik.yaml" − absolute URL
//   - "file:///home/user/apps/traefik.yaml" − local file URL
type AppIndex []string
