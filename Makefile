GOROOT       := /usr/local/go
GO           := $(GOROOT)/bin/go
GOPATH       := $(HOME)/tmp/gopath
BIN          := selfhosted
PNPM         := $(HOME)/.npm-global/bin/pnpm
GOOS         := linux
GOARCH       := amd64
LDFLAGS      := -s -w -X main.version=$(shell git describe --tags --always 2>/dev/null || echo dev) -X main.commit=$(shell git rev-parse --short HEAD 2>/dev/null || echo none) -X main.date=$(shell date -u +%Y-%m-%dT%H:%M:%SZ)
DIST_DIR     := cli/web/dist
DEV_DIR      := .dev
DEV_CONFIG   := $(PWD)/.selfhosted.dev.yaml
DEV_PID_FILE := $(DEV_DIR)/selfhosted.pid
BK_PID_FILE  := $(DEV_DIR)/backend.pid
FE_PID_FILE  := $(DEV_DIR)/frontend.pid

.PHONY: all build build-backend frontend test test-go test-e2e lint clean dev dev-frontend killdev makedev

all: build

## —— Build ——

frontend:
	@echo "→ Building frontend..."
	@cd frontend && CI=true $(PNPM) install --silent 2>/dev/null; npx --yes vue-tsc --noEmit && npx vite build --logLevel warn
	@echo "→ Frontend built to $(DIST_DIR)/"

build: frontend
	@echo "→ Building $(BIN) ($(GOOS)/$(GOARCH))..."
	@CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) $(GO) build -ldflags="$(LDFLAGS)" -o bin/$(BIN) ./cli
	@echo "→ bin/$(BIN)"

build-backend:
	@CGO_ENABLED=0 $(GO) build -ldflags="$(LDFLAGS)" -o bin/$(BIN)-backend ./backend/cmd/...

build-all: build build-backend

build-linux-amd64:
	@$(MAKE) build GOOS=linux GOARCH=amd64

build-linux-arm64:
	@$(MAKE) build GOOS=linux GOARCH=arm64

build-linux-arm:
	@$(MAKE) build GOOS=linux GOARCH=arm

build-darwin-amd64:
	@$(MAKE) build GOOS=darwin GOARCH=amd64

build-darwin-arm64:
	@$(MAKE) build GOOS=darwin GOARCH=arm64

## —— Test ——

test-go:
	@$(GO) test -v -race -count=1 ./contracts/... ./sdk/... ./cli/...

test-e2e:
	@cd frontend && $(PNPM) exec playwright test

test: test-go

## —— Lint ——

lint:
	@golangci-lint run ./contracts/... ./sdk/... ./cli/... ./backend/...

## —— Clean ——

clean:
	@rm -rf bin/ $(DIST_DIR) $(DEV_DIR)
	@cd frontend && rm -rf dist/ node_modules/.vite
	@echo "→ Cleaned"

## —— Dev (hot-reload) ——

killdev:
	@for f in $(DEV_PID_FILE) $(BK_PID_FILE) $(FE_PID_FILE); do \
		if [ -f $$f ]; then \
			PID=$$(cat $$f); \
			if kill -0 $$PID 2>/dev/null; then \
				echo "→ Killing PID $$PID..."; \
				kill $$PID 2>/dev/null; \
			fi; \
			rm -f $$f; \
		fi; \
	done
	@sleep 1

dev: killdev
	@mkdir -p $(DEV_DIR)
	@echo "→ Starting backend (go run) on :18080..."
	@echo "→ Using config: $(DEV_CONFIG)"
	@GOROOT=$(GOROOT) GOPATH=$(GOPATH) CGO_ENABLED=0 nohup $(GO) run -C $(PWD)/backend ./cmd/... -c $(DEV_CONFIG) --addr :18080 > $(DEV_DIR)/backend.log 2>&1 & echo $$! > $(BK_PID_FILE)
	@sleep 3
	@echo "→ Starting frontend (pnpm dev) on :5173..."
	@nohup $(PNPM) --prefix frontend run dev > $(PWD)/$(DEV_DIR)/frontend.log 2>&1 & echo $$! > $(FE_PID_FILE)
	@sleep 2
	@echo ""
	@echo "→ Backend:  http://localhost:18080/api/health"
	@echo "→ Frontend: http://localhost:5173"
	@echo ""
	@echo "Use 'make killdev' to stop"

makedev: killdev frontend
	@mkdir -p $(DEV_DIR)
	@echo "→ Building backend..."
	@CGO_ENABLED=0 $(GO) build -ldflags="$(LDFLAGS)" -o bin/$(BIN)-backend ./backend/cmd/...
	@echo "→ Building $(BIN)..."
	@CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) $(GO) build -ldflags="$(LDFLAGS)" -o bin/$(BIN) ./cli
	@echo "→ Starting dev server..."
	@nohup ./bin/$(BIN) serve > $(DEV_DIR)/server.log 2>&1 &
	@echo $$! > $(DEV_PID_FILE)
	@echo "→ Dev server started (PID $$(cat $(DEV_PID_FILE)))"
	@echo "→ Logs: $(DEV_DIR)/server.log"

dev-frontend:
	@cd frontend && $(PNPM) run dev

## —— Release ——

release: clean frontend
	@CGO_ENABLED=0 $(GO) build -ldflags="$(LDFLAGS)" -o bin/$(BIN)-linux-amd64 ./cli
	@CGO_ENABLED=0 GOARCH=arm64 $(GO) build -ldflags="$(LDFLAGS)" -o bin/$(BIN)-linux-arm64 ./cli
	@echo "→ Release binaries in bin/"
