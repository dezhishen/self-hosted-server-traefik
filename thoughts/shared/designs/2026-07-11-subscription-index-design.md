---
date: 2026-07-11
topic: "Subscription index.yaml refactoring"
status: validated
---

## Problem Statement

Current subscription system clones entire Git repos and expects a hardcoded `templates/services/` directory structure. This is inflexible, wasteful (clones entire repos), and tightly coupled to the project's own template layout. There's no manifest/catalog concept, making it hard to discover what templates are available or sync individual templates.

## Constraints

- index.yaml must be a flat YAML list of addresses (no complex objects)
- Support `http://`, `https://`, and `file://` URL schemas
- Relative paths in index.yaml resolve against the index.yaml's own URL
- Project's own 67 templates must also use index.yaml as the manifest
- No breaking changes to the frontend subscription UI
- Must work both locally (no network) and with remote subscription sync

## Approach

**index.yaml as the single manifest.** Both local built-in templates and remote subscriptions use the same index.yaml format — a flat YAML list of template addresses. The service loader and subscription manager both operate on this index.

- **ServiceLoader** reads `templates/index.yaml` (local) + each subscription's cached `index.yaml` to discover templates
- **SubscriptionManager.Sync()** fetches a remote index.yaml, resolves each entry (relative→absolute), downloads template files
- **Default subscription** points to the project's GitHub raw `templates/index.yaml`, but local templates are always available immediately

## Architecture

### New Files
- `templates/index.yaml` — project's own template manifest (67 entries)
- `contracts/index.go` — `TemplateIndex` type (just `[]string`)

### Modified Files
- `backend/service/loader.go` — index-aware loading instead of directory scan
- `backend/subscription/manager.go` — new Sync() using index download
- `backend/subscription/store.go` — adapt store if needed
- `backend/core/app.go` — initialize with local index + default subscription
- `backend/internal/server/server.go` — may need API adjustments
- `frontend/src/views/SubscriptionList.vue` — minor UI updates for categories/metadata
- `frontend/src/api/subscriptions.ts` — API types if needed

## Components

### 1. TemplateIndex (contracts/index.go)
```go
// TemplateIndex is a flat list of template addresses.
// Addresses can be:
//   - Relative path (e.g. "services/traefik.yaml") — resolved relative to index.yaml location
//   - Absolute URL (e.g. "https://...") — downloaded directly
//   - file:// URL — read from local filesystem
type TemplateIndex []string
```

### 2. Index Parser (backend/subscription/index.go — new utility)
- Parse a YAML file into `TemplateIndex`
- Resolve relative paths: given index URL `https://example.com/templates/index.yaml` and entry `services/traefik.yaml`, produce `https://example.com/templates/services/traefik.yaml`
- Fetch support: HTTP GET for remote, os.ReadFile for file://

### 3. ServiceLoader Changes
- **Before**: `loadDir(path)` scans `*.yaml` files in a directory
- **After**: `loadIndex(path)` reads `index.yaml`, iterates entries, loads each by resolved path
- Local templates: read `templates/index.yaml` → entries resolved relative to `templates/`
- Subscription templates: read `{dataDir}/templates/{name}/index.yaml` → entries resolved relative to that file's origin URL (for caching) or local path

### 4. SubscriptionManager Changes
- `Add(name, url)`: url now points directly to an index.yaml
- `Sync(name)`:
  1. Fetch index.yaml from subscription URL
  2. Parse into TemplateIndex
  3. For each entry, resolve the full URL
  4. Download each template file
  5. Save cached index.yaml + template files to `{dataDir}/templates/{name}/`
  6. Register path with ServiceLoader
- `Remove(name)`: clean up downloaded files (already works)
- `List()`: read cached indexes, return available template names

### 5. Default Subscription
- Pre-configured "community" subscription
- URL: `https://raw.githubusercontent.com/dezhishen/self-hosted-server-traefik/main/templates/index.yaml`
- Local templates always available via local `templates/index.yaml` — no network needed at startup
- Default subscription is a fallback for when users want to sync latest templates

## Data Flow

### Startup (no network)
```
NewApp()
  → ServiceLoader reads templates/index.yaml (local)
  → Loads 67 built-in templates via local relative paths
  → Registers default subscription metadata
  → Ready (all templates available immediately)
```

### Subscription Sync (user clicks "sync")
```
Sync("community")
  → HTTP GET https://raw.githubusercontent.com/.../main/templates/index.yaml
  → Parse YAML into TemplateIndex ([]string)
  → For each entry "services/xxx.yaml":
    → Resolve: https://raw.githubusercontent.com/.../main/services/xxx.yaml
    → HTTP GET → save to {dataDir}/templates/community/xxx.yaml
  → Save index.yaml to {dataDir}/templates/community/index.yaml
  → Add path to ServiceLoader
  → Return success
```

### Template Loading
```
ServiceLoader.LoadServices()
  → For each registered path:
    → Look for index.yaml in that path
    → Parse index → get template file list
    → Load each template YAML
  → Merge into master service map
  → Return available services
```

## Error Handling

- **Index fetch failure**: log error, return existing cached templates
- **Individual template download failure**: log warning, continue with rest, report count
- **Invalid index.yaml**: log error, don't clear existing templates, return error to UI
- **Checksum/validation**: none in v1 (downloaded as-is); can add later

## Testing Strategy

1. **Unit tests**: Index parsing, URL resolution, download manager
2. **Subscription manager tests**: Mock HTTP server serving index.yaml + templates
3. **Service loader tests**: Verify loadFromIndex vs loadFromDir
4. **Integration**: Full sync flow end-to-end

## Open Questions

(none — design validated)
