package server

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"github.com/dezhishen/self-hosted-server-traefik/backend/core"
	"github.com/dezhishen/self-hosted-server-traefik/backend/endpoint"
	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
	"github.com/dezhishen/self-hosted-server-traefik/backend/service"
	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

// ============================================================
// Handler 类型定义 — 所有 handler 返回 *APIError，由 handle 统一转换
// ============================================================

// apiHandler 是标准 handler，返回 *APIError。
// 成功时返回 nil，由 handle() 适配为 http.HandlerFunc。
type apiHandler func(http.ResponseWriter, *http.Request) *APIError

// apiHandlerWithEndpoint 是需要 endpoint 上下文的 handler。
type apiHandlerWithEndpoint func(http.ResponseWriter, *http.Request, *endpoint.Context) *APIError

// Server 是 HTTP API 服务器的核心结构。
type Server struct {
	app      *core.App
	sessions *sessionManager
	apiKeys  *apiKeyManager
}

func New(app *core.App) *Server {
	return &Server{
		app:      app,
		sessions: newSessionManager(),
		apiKeys:  newAPIKeyManager(app.Config.BaseDataDir, app.Logger),
	}
}

// ============================================================
// 拦截器适配器 — handle 系列函数将 apiHandler 转为 http.HandlerFunc
// 职责：仅在 apiHandler 返回非 nil 时写入 JSON 错误响应
// ============================================================

// handle 是核心拦截器。所有 apiHandler 都通过它适配为标准 HandlerFunc。
func (s *Server) handle(h apiHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := h(w, r); err != nil {
			s.writeError(w, err)
		}
	}
}

// handleWithEndpoint 是带 endpoint 解析的拦截器。
// 内置端点查找，找不到直接返回 JSON 错误，不进入业务 handler。
func (s *Server) handleWithEndpoint(h apiHandlerWithEndpoint) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		epName := r.Header.Get("X-Remote-Name")
		if epName == "" {
			epName = s.app.DefaultEndpoint
		}
		epCtx, ok := s.app.GetEndpoint(epName)
		if !ok {
			s.writeError(w, NotFoundError(ErrEndpointNotFound, "endpoint not found: "+epName).
				WithDetail("endpoint", epName))
			return
		}
		if err := h(w, r, epCtx); err != nil {
			s.writeError(w, err)
		}
	}
}

// ============================================================
// 中间件 — 返回 apiHandler，由 handle() 统一捕获错误
// ============================================================

// withAuth 是认证中间件。返回 *APIError，由 handle() 统一处理。
// 公开路由（login/logout/health/endpoints）透传。
// 其他路由：优先校验 Bearer session token，失败则尝试校验 API key。
func (s *Server) withAuth(next apiHandler) apiHandler {
	return func(w http.ResponseWriter, r *http.Request) *APIError {
		if isPublicRoute(r.URL.Path) {
			return next(w, r)
		}

		token, ok := extractBearerToken(r)
		if !ok {
			return AuthError(ErrUnauthorized, "missing or invalid authorization header")
		}

		// Try session token first
		if username, ok := s.sessions.ValidateSession(token); ok {
			ctx := context.WithValue(r.Context(), ctxAuthUserKey, username)
			return next(w, r.WithContext(ctx))
		}

		// Fallback to API key
		if scope, ok := s.apiKeys.Validate(token); ok {
			ctx := context.WithValue(r.Context(), ctxAuthUserKey, "apikey-"+scope)
			ctx = context.WithValue(ctx, ctxAuthKeyScope, scope)
			return next(w, r.WithContext(ctx))
		}

		return AuthError(ErrUnauthorized, "invalid or expired token")
	}
}

// ============================================================
// 路由注册
// ============================================================

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	// ===== 公开路由 =====
	mux.HandleFunc("/api/auth/login", s.handle(s.handleAuthLogin))
	mux.HandleFunc("/api/auth/logout", s.handle(s.handleAuthLogout))
	mux.HandleFunc("/api/health", s.handle(s.handleHealth))
	mux.HandleFunc("/api/endpoints", s.handle(s.handleEndpoints))

	// ===== 需认证路由 =====
	mux.HandleFunc("/api/config", s.handle(s.withAuth(s.handleConfig)))
	mux.HandleFunc("/api/config/password", s.handle(s.withAuth(s.handlePassword)))
	mux.HandleFunc("/api/services", s.handleWithEndpoint(s.handleServices))
	mux.HandleFunc("/api/services/", s.handleWithEndpoint(s.handleServiceByID))
	mux.HandleFunc("/api/containers", s.handleWithEndpoint(s.handleContainers))
	mux.HandleFunc("/api/migrate/analyze", s.handleWithEndpoint(s.handleMigrateAnalyze))
	mux.HandleFunc("/api/migrate/execute", s.handleWithEndpoint(s.handleMigrateExecute))
	mux.HandleFunc("/api/migrate/generate", s.handleWithEndpoint(s.handleMigrateGenerate))
	mux.HandleFunc("/api/migrate/adopt", s.handleWithEndpoint(s.handleMigrateAdopt))
	mux.HandleFunc("/api/ssh/keygen", s.handle(s.withAuth(s.handleSSHKeygen)))
	mux.HandleFunc("/api/ssh/import", s.handle(s.withAuth(s.handleSSHImport)))
	mux.HandleFunc("/api/ssh/keys", s.handle(s.withAuth(s.handleSSHKeys)))
	mux.HandleFunc("DELETE /api/ssh/keys/{name}", s.handle(s.withAuth(s.handleSSHKeyDelete)))
	mux.HandleFunc("/api/ssh/authorize", s.handle(s.withAuth(s.handleSSHAuthorize)))
	mux.HandleFunc("/api/subscriptions", s.handle(s.withAuth(s.handleSubscriptions)))
	mux.HandleFunc("/api/subscriptions/", s.handle(s.withAuth(s.handleSubscriptionByID)))

	// ===== API Key 管理 (仅 session auth) =====
	mux.HandleFunc("/api/apikeys", s.handle(s.withAuth(s.handleAPIKeys)))
	mux.HandleFunc("/api/apikeys/", s.handle(s.withAuth(s.handleAPIKeysByID)))

	return withLogging(s.app.Logger, mux)
}

func withLogging(log logger.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Info("request", logger.String("method", r.Method), logger.String("path", r.URL.Path), logger.String("remote", r.Header.Get("X-Remote-Name")))
		next.ServeHTTP(w, r)
	})
}

// ============================================================
// Handler — Auth
// ============================================================

// POST /api/auth/login
func (s *Server) handleAuthLogin(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}

	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body").
			WithCause(err)
	}
	if req.Username == "" || req.Password == "" {
		return ValidationError(ErrMissingField, "username and password are required")
	}

	if s.app.Config.Auth == nil || s.app.Config.Auth.PasswordHash == "" {
		return AuthError(ErrNoPasswordSet, "no password configured; use 'selfhosted passwd' to set one")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(s.app.Config.Auth.PasswordHash), []byte(req.Password)); err != nil {
		return AuthError(ErrUnauthorized, "invalid credentials")
	}

	token, err := s.sessions.CreateSession(req.Username)
	if err != nil {
		return InternalError(ErrSessionCreate, "failed to create session").
			WithCause(err)
	}

	s.app.Logger.Info("login successful", logger.String("username", req.Username))
	jsonResp(w, map[string]string{
		"token":    token,
		"username": req.Username,
	})
	return nil
}

// POST /api/auth/logout
func (s *Server) handleAuthLogout(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}
	if token, ok := extractBearerToken(r); ok {
		s.sessions.RevokeSession(token)
	}
	jsonResp(w, map[string]string{"status": "ok"})
	return nil
}

// ============================================================
// jsonResp — 保持原样，用于成功响应
// ============================================================

func jsonResp(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

// ============================================================
// Handler — API Keys
// ============================================================

// POST /api/apikeys  — create a new API key (body: {"scope":"...","description":"..."})
// GET  /api/apikeys  — list all API keys
func (s *Server) handleAPIKeys(w http.ResponseWriter, r *http.Request) *APIError {
	switch r.Method {
	case http.MethodPost:
		var req struct {
			Scope       string `json:"scope"`
			Description string `json:"description"`
		}
		if err := decodeJSON(r, &req); err != nil {
			return ValidationError(ErrInvalidJSON, "invalid request body").
				WithCause(err)
		}
		if req.Scope == "" {
			req.Scope = "cli"
		}
		entry, err := s.apiKeys.Create(req.Scope, req.Description)
		if err != nil {
			return InternalError(ErrInternal, "failed to create API key").
				WithCause(err)
		}
		s.app.Logger.Info("API key created",
			logger.String("scope", req.Scope),
			logger.String("description", req.Description),
		)
		jsonResp(w, entry)

	case http.MethodGet:
		keys := s.apiKeys.List()
		// mask key values for listing - only show first 8 chars
		type maskedKey struct {
			KeyPrefix   string `json:"key_prefix"`
			Scope       string `json:"scope"`
			Description string `json:"description"`
			CreatedAt   string `json:"created_at"`
		}
		result := make([]maskedKey, 0, len(keys))
		for _, k := range keys {
			prefix := k.Key
			if len(prefix) > 16 {
				prefix = prefix[:16] + "..."
			}
			result = append(result, maskedKey{
				KeyPrefix:   prefix,
				Scope:       k.Scope,
				Description: k.Description,
				CreatedAt:   k.CreatedAt.Format(time.RFC3339),
			})
		}
		jsonResp(w, result)

	default:
		return MethodNotAllowed()
	}
	return nil
}

// DELETE /api/apikeys/{key} — revoke an API key
func (s *Server) handleAPIKeysByID(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodDelete {
		return MethodNotAllowed()
	}
	// Extract key from path: /api/apikeys/{key}
	key := strings.TrimPrefix(r.URL.Path, "/api/apikeys/")
	if key == "" {
		return ValidationError(ErrMissingField, "API key is required")
	}
	if !s.apiKeys.Revoke(key) {
		return NotFoundError(ErrInternal, "API key not found")
	}
	s.app.Logger.Info("API key revoked")
	jsonResp(w, map[string]string{"status": "ok"})
	return nil
}

// ============================================================
// Handler — Health
// ============================================================

// GET /api/health
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) *APIError {
	engine := ""
	epCount := len(s.app.Endpoints)
	if epCtx, ok := s.app.GetEndpoint(s.app.DefaultEndpoint); ok {
		if rt := epCtx.Runtime; rt != nil {
			if info, err := rt.Info(); err == nil {
				engine = string(info.Engine)
			}
		}
	}
	jsonResp(w, map[string]interface{}{
		"status":    "ok",
		"endpoints": epCount,
		"engine":    engine,
	})
	return nil
}

// ============================================================
// Handler — Config
// ============================================================

// GET /api/config
// PUT /api/config
func (s *Server) handleConfig(w http.ResponseWriter, r *http.Request) *APIError {
	switch r.Method {
	case http.MethodGet:
		// Resolve SSH key metadata from key store for each endpoint
		for _, ep := range s.app.Config.Endpoints {
			if ep.Connection == nil || ep.Connection.SSHKeyRef == "" {
				continue
			}
			if s.app.SSHKeyManager == nil {
				continue
			}
			if fp, kt, pub, ok := s.app.SSHKeyManager.Resolve(ep.Connection.SSHKeyRef); ok {
				ep.Connection.SSHKeyFingerprint = fp
				ep.Connection.SSHKeyType = kt
				ep.Connection.SSHPublicKey = pub
			}
		}
		jsonResp(w, s.app.Config)
		return nil

	case http.MethodPut:
		var incoming contracts.AppConfig
		if err := json.NewDecoder(r.Body).Decode(&incoming); err != nil {
			return ValidationError(ErrInvalidJSON, "invalid request body").
				WithCause(err)
		}

		// No SSHPrivateKey preservation needed — keys are independent in ssh_keys.yaml.
		// Validate that referenced SSH keys exist in the key store.
		for name, ep := range incoming.Endpoints {
			if ep.Connection == nil || ep.Connection.SSHKeyRef == "" {
				continue
			}
			if s.app.SSHKeyManager != nil {
				if _, ok := s.app.SSHKeyManager.Get(ep.Connection.SSHKeyRef); !ok {
					return ValidationError(ErrInvalidValue, "SSH key not found: "+ep.Connection.SSHKeyRef).
						WithDetail("endpoint", name).
						WithDetail("ssh_key_ref", ep.Connection.SSHKeyRef)
				}
			}
		}

		if err := s.app.ConfigMgr.SavePut(&incoming); err != nil {
			return InternalError(ErrConfigSave, "failed to save config").
				WithCause(err)
		}

		s.app.Config.Endpoints = incoming.Endpoints
		if incoming.Auth != nil && incoming.Auth.Username != "" {
			s.app.Config.Auth.Username = incoming.Auth.Username
		}
		s.app.RefreshEndpoints()

		jsonResp(w, map[string]string{"status": "ok"})
		return nil

	default:
		return MethodNotAllowed()
	}
}

// POST /api/config/password
func (s *Server) handlePassword(w http.ResponseWriter, r *http.Request) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}

	var req struct {
		Password string `json:"password"`
	}
	if err := decodeJSON(r, &req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body").
			WithCause(err)
	}
	if req.Password == "" {
		return ValidationError(ErrMissingField, "password is required")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return InternalError(ErrPasswordHash, "failed to hash password").
			WithCause(err)
	}

	if s.app.Config.Auth == nil {
		s.app.Config.Auth = &contracts.AuthConfig{}
	}
	s.app.Config.Auth.PasswordHash = string(hash)

	if err := s.app.ConfigMgr.SaveSystem(s.app.Config.BaseDataDir, s.app.Config.Auth); err != nil {
		return InternalError(ErrConfigSave, "failed to save password").
			WithCause(err)
	}

	s.app.Logger.Info("password updated via web UI")
	jsonResp(w, map[string]string{"status": "ok"})
	return nil
}

// ============================================================
// Handler — Endpoints
// ============================================================

// GET /api/endpoints
func (s *Server) handleEndpoints(w http.ResponseWriter, r *http.Request) *APIError {
	eps := make([]*contracts.EndpointConfig, 0, len(s.app.Config.Endpoints))
	for _, ep := range s.app.Config.Endpoints {
		eps = append(eps, ep)
	}
	jsonResp(w, eps)
	return nil
}

// ============================================================
// Handler — Services
// ============================================================

// GET /api/services
// POST /api/services (install)
func (s *Server) handleServices(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) *APIError {
	switch r.Method {
	case http.MethodGet:
		category := r.URL.Query().Get("category")
		query := r.URL.Query().Get("query")
		var services []*contracts.ServiceDefinition
		var err error
		switch {
		case query != "":
			services, err = ep.ServiceManager.Search(query)
		case category != "":
			services, err = ep.ServiceManager.GetByCategory(category)
		default:
			services, err = ep.ServiceManager.List()
		}
		if err != nil {
			return InternalError(ErrInternal, "failed to list services").
				WithCause(err)
		}
		jsonResp(w, services)
		return nil

	case http.MethodPost:
		var req struct {
			Name   string                `json:"name"`
			Params []*contracts.ParamValue `json:"params"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			return ValidationError(ErrInvalidJSON, "invalid request body")
		}

		id, err := ep.ServiceManager.Install(req.Name, req.Params, ep.Name)
		if err != nil {
			return InfrastructureError(ErrDockerOperation, err.Error()).
				WithCause(err).
				WithDetail("service", req.Name)
		}
		jsonResp(w, map[string]string{"container_id": id})
		return nil

	default:
		return MethodNotAllowed()
	}
}

// GET /api/services/{name}
// DELETE /api/services/{name}
// POST /api/services/{name}/status|restart|logs|render|params
// PUT /api/services/{name}/params
func (s *Server) handleServiceByID(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) *APIError {
	path := strings.TrimPrefix(r.URL.Path, "/api/services/")
	parts := strings.SplitN(path, "/", 2)
	name := parts[0]
	action := ""
	if len(parts) > 1 {
		action = parts[1]
	}

	switch {
	case r.Method == http.MethodGet && action == "":
		svc, err := ep.ServiceManager.Get(name)
		if err != nil {
			return NotFoundError(ErrServiceNotFound, err.Error()).
				WithDetail("service", name)
		}
		status, _ := ep.ServiceManager.Status(name)
		jsonResp(w, map[string]interface{}{
			"definition": svc,
			"status":     status,
		})
		return nil

	case r.Method == http.MethodDelete && action == "":
		if err := ep.ServiceManager.Uninstall(name); err != nil {
			return InfrastructureError(ErrDockerOperation, err.Error()).
				WithCause(err).
				WithDetail("service", name)
		}
		jsonResp(w, map[string]string{"status": "ok"})
		return nil

	case r.Method == http.MethodPost && action == "status":
		status, err := ep.ServiceManager.Status(name)
		if err != nil {
			return InternalError(ErrInternal, "failed to get status").
				WithCause(err).
				WithDetail("service", name)
		}
		jsonResp(w, status)
		return nil

	case r.Method == http.MethodPost && action == "restart":
		if err := ep.ServiceManager.Restart(name); err != nil {
			return InfrastructureError(ErrDockerOperation, err.Error()).
				WithCause(err).
				WithDetail("service", name)
		}
		jsonResp(w, map[string]string{"status": "ok"})
		return nil

	case r.Method == http.MethodPost && action == "logs":
		tail := 100
		var body struct {
			Tail int `json:"tail"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err == nil && body.Tail > 0 {
			tail = body.Tail
		}
		containers, err := ep.Runtime.ContainerList(true)
		if err != nil {
			return InfrastructureError(ErrDockerOperation, err.Error()).
				WithCause(err)
		}
		for _, c := range containers {
			if c.Labels[contracts.ManagedServiceLabel] == name {
				logs, err := ep.Runtime.ContainerLogs(c.ID, tail)
				if err != nil {
					return InfrastructureError(ErrDockerOperation, err.Error()).
						WithCause(err)
				}
				jsonResp(w, map[string]string{"logs": logs})
				return nil
			}
		}
		return NotFoundError(ErrServiceNotFound, "service not installed").
			WithDetail("service", name)

	case r.Method == http.MethodPost && action == "render":
		var req struct {
			Params []*contracts.ParamValue `json:"params"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			return ValidationError(ErrInvalidJSON, "invalid request")
		}
		cfg, err := ep.ServiceManager.RenderConfig(name, req.Params)
		if err != nil {
			return InternalError(ErrInternal, err.Error()).
				WithCause(err).
				WithDetail("service", name)
		}
		jsonResp(w, cfg)
		return nil

	case r.Method == http.MethodPost && action == "params":
		params, err := ep.ParamStore.GetAll()
		if err != nil {
			return InternalError(ErrInternal, "failed to get params").
				WithCause(err).
				WithDetail("service", name)
		}
		jsonResp(w, params)
		return nil

	case r.Method == http.MethodPut && action == "params":
		var pv contracts.ParamValue
		if err := json.NewDecoder(r.Body).Decode(&pv); err != nil {
			return ValidationError(ErrInvalidJSON, "invalid request")
		}
		if err := ep.ParamStore.Set(&pv); err != nil {
			return InternalError(ErrInternal, err.Error()).
				WithCause(err)
		}
		jsonResp(w, map[string]string{"status": "ok"})
		return nil

	default:
		return NotFoundError(ErrServiceNotFound, "not found")
	}
}

// ============================================================
// Handler — Containers
// ============================================================

// GET /api/containers?all=true
func (s *Server) handleContainers(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) *APIError {
	if r.Method != http.MethodGet {
		return MethodNotAllowed()
	}
	all := r.URL.Query().Get("all") == "true"
	containers, err := ep.Runtime.ContainerList(all)
	if err != nil {
		return InfrastructureError(ErrDockerOperation, "failed to list containers").
			WithCause(err)
	}
	jsonResp(w, containers)
	return nil
}

// ============================================================
// Handler — Subscriptions
// ============================================================

// GET /api/subscriptions
// POST /api/subscriptions
func (s *Server) handleSubscriptions(w http.ResponseWriter, r *http.Request) *APIError {
	subMgr := s.app.SubscriptionManager()
	if subMgr == nil {
		return InternalError(ErrInternal, "subscription manager not available")
	}
	switch r.Method {
	case http.MethodGet:
		subs, err := subMgr.List()
		if err != nil {
			return InternalError(ErrInternal, "failed to list subscriptions").
				WithCause(err)
		}
		jsonResp(w, subs)
		return nil

	case http.MethodPost:
		var req struct {
			Name string `json:"name"`
			URL  string `json:"url"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			return ValidationError(ErrInvalidJSON, "invalid request")
		}
		if req.Name == "" || req.URL == "" {
			return ValidationError(ErrMissingField, "name and url are required")
		}
		if err := subMgr.Add(&contracts.Subscription{Name: req.Name, URL: req.URL, Enabled: true}); err != nil {
			return InternalError(ErrInternal, err.Error()).
				WithCause(err)
		}
		jsonResp(w, map[string]string{"status": "ok"})
		return nil

	default:
		return MethodNotAllowed()
	}
}

// POST /api/subscriptions/{name}/sync
// DELETE /api/subscriptions/{name}
func (s *Server) handleSubscriptionByID(w http.ResponseWriter, r *http.Request) *APIError {
	name := strings.TrimPrefix(r.URL.Path, "/api/subscriptions/")
	parts := strings.SplitN(name, "/", 2)
	name = parts[0]
	action := ""
	if len(parts) > 1 {
		action = parts[1]
	}

	subMgr := s.app.SubscriptionManager()
	if subMgr == nil {
		return InternalError(ErrInternal, "subscription manager not available")
	}

	switch {
	case r.Method == http.MethodPost && action == "sync":
		// Sync runs in background so the API doesn't block for 65+ HTTP downloads.
		go func() {
			if err := subMgr.Sync(name); err != nil {
				s.app.Logger.Error("subscription sync failed",
					logger.String("name", name),
					logger.Error(err),
				)
				return
			}
			// Register the synced template directory so the ServiceLoader
			// can find templates from this subscription immediately.
			subTmplDir := filepath.Join(s.app.Config.BaseDataDir, "templates", name)
			if _, err := os.Stat(filepath.Join(subTmplDir, "index.yaml")); err == nil {
				if loader, ok := s.app.ServiceLoader.(*service.Loader); ok {
					loader.AddPath(subTmplDir)
					s.app.Logger.Info("registered subscription templates",
						logger.String("name", name),
						logger.String("dir", subTmplDir),
					)
				}
			}
		}()
		jsonResp(w, map[string]string{"status": "syncing"})
		return nil

	case r.Method == http.MethodDelete:
		if err := subMgr.Remove(name); err != nil {
			return InternalError(ErrInternal, err.Error()).
				WithCause(err).
				WithDetail("subscription", name)
		}
		jsonResp(w, map[string]string{"status": "ok"})
		return nil

	default:
		return MethodNotAllowed()
	}
}

// ============================================================
// Handler — Migration
// ============================================================

// GET /api/migrate/analyze
func (s *Server) handleMigrateAnalyze(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) *APIError {
	if r.Method != http.MethodGet {
		return MethodNotAllowed()
	}
	candidates, err := ep.MigrateService.Analyze(ep.Name)
	if err != nil {
		return InternalError(ErrInternal, err.Error()).
			WithCause(err)
	}
	jsonResp(w, candidates)
	return nil
}

// POST /api/migrate/execute
func (s *Server) handleMigrateExecute(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}
	var req contracts.MigrationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body")
	}
	newID, err := ep.MigrateService.Execute(&req)
	if err != nil {
		return InternalError(ErrInternal, err.Error()).
			WithCause(err)
	}
	jsonResp(w, map[string]string{"container_id": newID})
	return nil
}

// POST /api/migrate/generate
func (s *Server) handleMigrateGenerate(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}
	var req contracts.GenerateTemplateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body")
	}
	if req.ContainerID == "" || req.ServiceName == "" {
		return ValidationError(ErrMissingField, "container_id and service_name are required")
	}
	result, err := ep.MigrateService.Generate(&req)
	if err != nil {
		return InternalError(ErrInternal, err.Error()).
			WithCause(err)
	}
	jsonResp(w, result)
	return nil
}

// POST /api/migrate/adopt
func (s *Server) handleMigrateAdopt(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) *APIError {
	if r.Method != http.MethodPost {
		return MethodNotAllowed()
	}
	var req contracts.AdoptRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		return ValidationError(ErrInvalidJSON, "invalid request body")
	}
	if req.ContainerID == "" {
		return ValidationError(ErrMissingField, "container_id is required")
	}
	result, err := ep.MigrateService.Adopt(&req)
	if err != nil {
		return InternalError(ErrInternal, err.Error()).
			WithCause(err)
	}
	jsonResp(w, result)
	return nil
}

func (s *Server) Start(addr string) error {
	s.app.Logger.Info("starting backend API server", logger.String("addr", addr))
	return http.ListenAndServe(addr, s.Handler())
}
