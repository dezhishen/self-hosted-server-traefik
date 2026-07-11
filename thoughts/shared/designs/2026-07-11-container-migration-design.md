---
date: 2026-07-11
topic: "Container Migration — Adopt Existing Containers into Management"
status: draft
---

## Problem Statement

Users have existing containers running on their Docker hosts before installing SelfHosted. Currently, the system only manages containers deployed through its service template system (identified via `selfhosted.*` labels). Unmanaged containers are invisible to the management layer — they can't be updated, monitored, or controlled through the UI.

We need a way to **adopt** an existing container: inspect it, match it to a known service template, extract its configuration as template parameters, stop the old container, and redeploy it with management labels attached.

## Constraints

- The existing container must keep working — data volumes, networks, and runtime state must be preserved
- The migration is **destructive** to the old container (it will be stopped and removed), but **non-destructive** to data (volumes are reused)
- Service templates may not perfectly match existing container configurations — we need a **best-effort parameter extraction** + manual override
- Must handle containers that don't match any known service template (user can still adopt them with a manual service definition)
- Existing `ContainerInspect` in the runtime interface lacks `Env` field — needs extension

## Approach

I'm choosing a **wizard-based migration flow** with two backend endpoints:

1. **Analyze** — inspect all containers, match against service templates, return a migration plan
2. **Execute** — given a container-to-service mapping with parameter overrides, stop old container and install via the standard template pipeline

**Why not auto-migrate everything in one shot?** Because parameter extraction is inherently lossy — env vars map to template params, but port/host mappings, device paths, and volume paths may need user adjustment. A review step prevents data loss.

## Architecture

### Backend changes

**1. Extend `ContainerInfo` with `Env` field**

Add `Env map[string]string` to the existing struct so we can inspect container environment variables for parameter extraction.

**2. Add `Images` field to `ServiceDefinition`**

Each service template gets an optional `images` field — a list of Docker image patterns (exact or prefix) that identify this service:
```yaml
images:
  - "linuxserver/jellyfin*"
  - "jellyfin/jellyfin*"
```

This is the matching key: container image → service template.

**3. New service `AdoptService` / `MigrateService` in `contracts`**

Interface:
```go
type MigrateService interface {
    // Analyze inspects all containers and matches them against available service templates.
    // Returns a list of migration candidates.
    Analyze(epName string) ([]*MigrationCandidate, error)
    
    // Execute performs the migration for a single container-to-service mapping.
    Execute(req *MigrationRequest) (string, error)
}

type MigrationCandidate struct {
    Container   *ContainerInfo          `json:"container"`
    MatchedService string               `json:"matched_service"` // empty if no match
    Services       []string             `json:"services"`        // all possible matches
    ExtractedParams []*ParamValue       `json:"extracted_params"`
}

type MigrationRequest struct {
    ContainerID    string        `json:"container_id"`
    ServiceName    string        `json:"service_name"`
    Params         []*ParamValue `json:"params"`          // user-reviewed params
    RemoveOld      bool          `json:"remove_old"`       // stop+remove old container?
}
```

**4. `migrateService` implementation in `endpoint` package**

The matching logic:
```go
func (m *migrateService) matchContainer(container *ContainerInfo, services []*ServiceDefinition) string {
    for _, svc := range services {
        for _, pattern := range svc.Images {
            if matched, _ := filepath.Match(pattern, container.Image); matched {
                return svc.Name
            }
        }
    }
    return ""
}
```

Parameter extraction logic (`extractParams`):
- For each `ParamDef` in the matched service:
  - If `EnvMapping` is defined: look up the env var in the container's `Env` map
  - If the param has a `label` matching a Docker label convention: check container labels
  - For port params: compare container ports against template port mappings
  - For volume params: compare container mounts against template volume mounts
- Return extracted values as `ParamValue` list, with empty values for unmapped params

Execute logic:
1. If `RemoveOld`: stop container → remove container
2. Call existing `ServiceManager.Install(name, params, epName)` — this pulls image, creates container with managed labels
3. Return new container ID

**5. New API endpoints**

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| `GET` | `/api/endpoints/{name}/migrate/analyze` | `handleMigrateAnalyze` | List containers, match to services, extract params |
| `POST` | `/api/endpoints/{name}/migrate/execute` | `handleMigrateExecute` | Execute migration for one container |

### Frontend changes

**New view: `Migration.vue`** — accessible from the user dropdown menu (alongside Settings/Subscriptions):

1. **Step 1: Unmanaged containers list**
   - Table of containers that DON'T have `selfhosted.managed=true` label
   - Columns: Container Name, Image, Status, Detected Service (auto-match)
   - "Details" button per container

2. **Step 2: Container detail + service selection**
   - Shows container's current config (image, env, ports, volumes, labels)
   - Dropdown to select service template (pre-filled if auto-matched)
   - Parameter form pre-filled with extracted values
   - User can adjust any parameter

3. **Step 3: Confirm migration**
   - Summary: "Stop & remove old container → Install new managed container"
   - "Migrate" button
   - Result: new container ID + success/failure message

**Integration**: Add "Migration" item in the user dropdown header menu, navigating to `/migrate`.

## Data Flow

```
User clicks "Migration" → GET /api/endpoints/{name}/migrate/analyze
  → Backend lists all containers via Runtime.ContainerList(true)
  → Filter out already-managed (selfhosted.managed=true)
  → For each unmanaged container:
      → Load all service templates
      → Match container.Image against service.Images patterns
      → Extract params from container Env/Ports/Volumes
      → Return MigrationCandidate[]
  → Frontend displays table

User selects container → reviews params → clicks "Migrate"
  → POST /api/endpoints/{name}/migrate/execute
  → Backend:
      1. Stop old container (ContainerStop)
      2. Remove old container (ContainerRemove, force=true)
      3. ServiceManager.Install(name, reviewedParams, epName)
         → Pulls image
         → Builds ContainerRunParams with managed labels
         → ContainerRun
      4. Return new container ID
  → Frontend shows success + link to service detail
```

## Error Handling

- **Container already managed**: Skip in analyze; return error if user tries to migrate again
- **No matching service**: Allow manual service selection from full service list
- **Parameter extraction fails for required param**: Mark as missing, require user input
- **Install fails after old container removed**: Critical — log full error, show rollback instructions. Old container is already gone, so the user needs to know exactly what params were used to retry
- **Image pull fails**: Stop here — don't remove old container until we know we can create the new one

## Open Questions

1. Should we support adopting containers that don't match ANY service template? (Yes — user should be able to pick a service manually, or we could create an "adopted" generic service type)
2. Should the old container name be preserved for the new one? (I lean yes — keeps container naming consistent)
3. Should we add a "dry-run" mode? (Low priority — YAGNI for now)
4. How should volumes be handled? The old container's bind mounts need to be transferred. If the template defines `/config` but the user's existing container has `/etc/myapp/config` — this needs manual mapping. I think the UI should show the discrepancy.

## Testing Strategy

- **Unit tests**: `matchContainer` matching logic, `extractParams` extraction for each param type
- **Integration test**: Full migration flow with a Docker test container:
  1. Create an unmanaged container via raw Docker API
  2. Run analyze — verify it's detected and matched
  3. Run execute — verify old container is removed, new one has managed labels
  4. Verify `ServiceManager.Status()` returns "running"
- **Frontend test**: Verify migration view loads, table shows containers, parameter form renders
