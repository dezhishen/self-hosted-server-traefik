package contracts

// TemplateIndex is a flat list of template addresses.
//
// Each entry is a relative path or absolute URL pointing to a template YAML file.
// Relative paths are resolved relative to the index.yaml's own location.
//
// Examples:
//   - "services/traefik.yaml" − relative path (resolved against index location)
//   - "https://example.com/templates/traefik.yaml" − absolute URL
//   - "file:///home/user/templates/traefik.yaml" − local file URL
type TemplateIndex []string
