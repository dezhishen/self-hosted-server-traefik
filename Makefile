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
DEV_CONFIG   := $(CURDIR)/.selfhosted.dev
DEV_PID_FILE := $(DEV_DIR)/selfhosted.pid
BK_PID_FILE  := $(DEV_DIR)/backend.pid
FE_PID_FILE  := $(DEV_DIR)/frontend.pid

.PHONY: all build build-backend frontend test test-go test-e2e lint clean dev dev-frontend killdev makedev passwd

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

test-e2e: build-backend
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
	@# Kill by PID files
	@for f in $(DEV_PID_FILE) $(BK_PID_FILE) $(FE_PID_FILE); do \
		if [ -f $$f ]; then \
			PID=$$(cat $$f); \
			kill $$PID 2>/dev/null && echo "→ Killed PID $$PID from $$(basename $$f)" || true; \
			rm -f $$f; \
		fi; \
	done
	@# Kill leftover go-run processes (both the shim and compiled binary)
	@for pid in $$(ps aux | grep -E 'go.*run.*backend.*cmd|go-build.*/cmd' | grep -v grep | awk '{print $$2}'); do \
		kill -9 $$pid 2>/dev/null && echo "→ Killed go-run PID $$pid" || true; \
	done
	@# Kill leftover vite processes
	@for pid in $$(ps aux | grep '[n]ode.*vite' | awk '{print $$2}'); do \
		kill $$pid 2>/dev/null && echo "→ Killed vite PID $$pid" || true; \
	done
	@sleep 2

dev: killdev
	@mkdir -p $(DEV_DIR)
	@echo "→ Starting frontend (vite) on :5173..."
	@rm -f $(DEV_DIR)/frontend.log
	@cd frontend && nohup npx vite --host 0.0.0.0 --port 5173 > $(CURDIR)/$(DEV_DIR)/frontend.log 2>&1 & echo $$! > $(CURDIR)/$(FE_PID_FILE)
	@sleep 3
	@FE_PORT=$$(grep -oP 'Local:\s+http://localhost:\K\d+' $(DEV_DIR)/frontend.log 2>/dev/null || echo "5173"); \
	IP=$$(hostname -I 2>/dev/null | awk '{print $$1}'); \
	[ -z "$$IP" ] && IP="localhost"; \
	echo "→ Frontend:  http://$$IP:$$FE_PORT"; \
	echo "→ Starting backend on :18080..."; \
	echo "→ Backend:   http://$$IP:18080/api/health"; \
	echo "→ Press Ctrl+C to stop both"; \
	echo ""; \
	cleanup() { echo "→ Stopping frontend (PID $$(cat $(FE_PID_FILE) 2>/dev/null))..."; kill -9 $$(cat $(FE_PID_FILE) 2>/dev/null) 2>/dev/null; rm -f $(FE_PID_FILE) $(BK_PID_FILE); }; \
	trap cleanup EXIT; \
	$(GO) run -C $(CURDIR)/backend ./cmd/... -c $(DEV_CONFIG) --addr :18080

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

## —— Passwd ——

passwd:
	@mkdir -p $(DEV_DIR)
	@PASSWORD="$(or $(PASSWORD),"")"; \
	if [ -z "$$PASSWORD" ]; then \
		$(GO) run -C $(CURDIR)/backend ./cmd/... -c $(DEV_CONFIG) passwd; \
	else \
		$(GO) run -C $(CURDIR)/backend ./cmd/... -c $(DEV_CONFIG) passwd "$$PASSWORD"; \
	fi

dev-frontend:
	@cd frontend && $(PNPM) run dev

## —— Release ——

release: clean frontend
	@CGO_ENABLED=0 $(GO) build -ldflags="$(LDFLAGS)" -o bin/$(BIN)-linux-amd64 ./cli
	@CGO_ENABLED=0 GOARCH=arm64 $(GO) build -ldflags="$(LDFLAGS)" -o bin/$(BIN)-linux-arm64 ./cli
	@echo "→ Release binaries in bin/"
