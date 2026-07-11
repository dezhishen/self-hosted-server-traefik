# Container Migration Feature — Implementation Plan

## Phase 1: Backend Contracts

### Task 1.1 — Add `Env` to `ContainerInfo`
- **File**: `contracts/runtime.go`
- **Change**: Add `Env map[string]string` field to `ContainerInfo` struct
- **Test**: Verify struct compiles and marshals JSON correctly

### Task 1.2 — Add `Images` to `ServiceDefinition`
- **File**: `contracts/service.go`
- **Change**: Add `Images []string` field to `ServiceDefinition`
- **Test**: Verify YAML/JSON round-trip

### Task 1.3 — Create `contracts/migrate.go`
- **New file**: `contracts/migrate.go`
- **Contents**:
  ```go
  type MigrateService interface {
      Analyze(epName string) ([]*MigrationCandidate, error)
      Execute(req *MigrationRequest) (string, error)
  }
  type MigrationCandidate struct {
      Container      *ContainerInfo `json:"container"`
      MatchedService string         `json:"matched_service"`
      Services       []string       `json:"services"`
      ExtractedParams []*ParamValue `json:"extracted_params"`
  }
  type MigrationRequest struct {
      ContainerID string        `json:"container_id"`
      ServiceName string        `json:"service_name"`
      Params      []*ParamValue `json:"params"`
      RemoveOld   bool          `json:"remove_old"`
  }
  ```
- **Test**: Verify struct compilation

## Phase 2: Backend Migration Service

### Task 2.1 — Implement `migrateService`
- **New file**: `backend/endpoint/migrate.go`
- **Struct**: `migrateService` with reference to `ContainerRuntime` and `ServiceLoader`
- **Methods**:
  - `matchContainer(container, services) string` — matches Image against Images patterns using `filepath.Match`
  - `extractParams(container, service) []*ParamValue` — extracts from Env/Ports/Volumes
  - `Analyze() ([]*MigrationCandidate, error)` — lists all containers, filters managed, matches+extracts
  - `Execute(req) (string, error)` — stop old → remove → `ServiceManager.Install(name, params, epName)`
- **Test**: Unit test matchContainer with various image patterns

### Task 2.2 — Wire into Context
- **File**: `backend/endpoint/context.go`
- **Change**: Add `MigrateService` field to `Context`, create in `NewContext()`

## Phase 3: Backend API

### Task 3.1 — Add migration handlers
- **File**: `backend/internal/server/server.go`
- **Add handlers**:
  - `handleMigrateAnalyze(w, r, ep)` — delegates to `ep.MigrateService.Analyze()`
  - `handleMigrateExecute(w, r, ep)` — delegates to `ep.MigrateService.Execute()`
- **Register routes** in `Handler()`:
  - `GET /api/migrate/analyze` → `s.withEndpoint(s.handleMigrateAnalyze)`
  - `POST /api/migrate/execute` → `s.withEndpoint(s.handleMigrateExecute)`
- **Test**: API contract tests

## Phase 4: Frontend

### Task 4.1 — Migration view
- **New file**: `frontend/src/views/Migration.vue`
- **Flow**:
  1. On mount: `GET /api/migrate/analyze` → display table of unmanaged containers
  2. Each row: container name, image, status, matched service (dropdown), "Details" button
  3. Details: show container config + param extraction results + editable param form
  4. "Migrate" button → `POST /api/migrate/execute` → show success/error

### Task 4.2 — Route + Dropdown integration
- **File**: `frontend/src/router/index.ts` — add `/migrate` → Migration route
- **File**: `frontend/src/components/SdLayout.vue` — add "Migration" item to user dropdown (above Settings)
- **File**: `frontend/src/i18n/locales/en.json` — add `nav.migration: "Migration"`
- **File**: `frontend/src/i18n/locales/zh-CN.json` — add `nav.migration: "迁移"`
