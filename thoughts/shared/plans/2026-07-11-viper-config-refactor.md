# Viper Config Refactoring - Implementation Plan

## Phase 1: Config Loader → Viper
**Files to modify:**
1. `backend/go.mod` — add `github.com/spf13/viper` dependency
2. `backend/config/loader.go` — full rewrite using viper
3. `backend/core/config.go` — migrate SaveEndpoints/SaveSystem/loadSystemFromDisk to viper

**Task structure:**
- Task 1a: Add viper dependency, rewrite `backend/config/loader.go` with viper-based Load/Save
- Task 1b: Migrate `backend/core/config.go` methods to use viper (SaveEndpoints, SaveSystem, loadSystemFromDisk)

## Phase 2: Subscription git clone → HTTP tarball
**Files to modify:**
1. `backend/subscription/manager.go` — replace Sync() git clone with HTTP tarball download

**Task structure:**
- Task 2a: Add HTTP tarball download + zip extraction to Sync(), keep git fallback

## Phase 3: Podman Adapter → moby SDK
**Files to modify:**
1. `backend/adapter/podman/runtime.go` — full rewrite using moby SDK

**Task structure:**
- Task 3a: Rewrite Podman runtime to use moby SDK client (delegate to Docker-compatible socket)

## Phase 4: Endpoint Factory → socket detection
**Files to modify:**
1. `backend/endpoint/factory.go` — replace LookPath with socket dial

**Task structure:**
- Task 4a: Replace exec.LookPath with net.Dial socket detection

## Verification
- `go build ./...` — must pass
- `go vet ./...` — must pass
- Existing tests must pass

## Order: Parallel tasks first, then serial
- Tasks 1a, 2a, 3a can run in parallel (independent files)
- Task 4a depends on Phase 3 being done
- Task 1b depends on Phase 1 being done
- Verification runs last
