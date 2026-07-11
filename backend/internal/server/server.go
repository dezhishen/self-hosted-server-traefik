package server

import (
	"encoding/json"
	"net/http"
	"strings"

	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"

	"github.com/dezhishen/self-hosted-server-traefik/backend/core"
	"github.com/dezhishen/self-hosted-server-traefik/backend/endpoint"
	"github.com/dezhishen/self-hosted-server-traefik/contracts"
)

type Server struct {
	app *core.App
}

func New(app *core.App) *Server {
	return &Server{app: app}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", s.handleHealth)
	mux.HandleFunc("/api/config", s.handleConfig)

	// Endpoint-scoped endpoints
	mux.HandleFunc("/api/services", s.withEndpoint(s.handleServices))
	mux.HandleFunc("/api/services/", s.withEndpoint(s.handleServiceByID))
	mux.HandleFunc("/api/containers", s.withEndpoint(s.handleContainers))

	// Global endpoints
	mux.HandleFunc("/api/endpoints", s.handleEndpoints)
	mux.HandleFunc("/api/ssh/keygen", s.handleSSHKeygen)
	mux.HandleFunc("/api/ssh/import", s.handleSSHImport)
	mux.HandleFunc("/api/ssh/keys", s.handleSSHKeys)
	mux.HandleFunc("/api/config/password", s.handlePassword)
	mux.HandleFunc("/api/subscriptions", s.handleSubscriptions)
	mux.HandleFunc("/api/subscriptions/", s.handleSubscriptionByID)

	return withLogging(s.app.Logger, mux)
}

func withLogging(log *zap.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Info("request", zap.String("method", r.Method), zap.String("path", r.URL.Path), zap.String("remote", r.Header.Get("X-Remote-Name")))
		next.ServeHTTP(w, r)
	})
}

func (s *Server) withEndpoint(next func(http.ResponseWriter, *http.Request, *endpoint.Context)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		epName := r.Header.Get("X-Remote-Name")
		if epName == "" {
			epName = s.app.DefaultEndpoint
		}
		epCtx, ok := s.app.GetEndpoint(epName)
		if !ok {
			jsonErr(w, 404, "endpoint not found: "+epName)
			return
		}
		next(w, r, epCtx)
	}
}

func jsonResp(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func jsonErr(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

// GET /api/health
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
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
}

// GET/PUT /api/config
func (s *Server) handleConfig(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		// Compute SSH key metadata for endpoints with private keys.
		// These fields (fingerprint, type) are derived from the private key
		// and NOT directly settable via JSON.
		for _, ep := range s.app.Config.Endpoints {
			if ep.Connection != nil && ep.Connection.SSHPrivateKey != "" {
				computeSSHKeyMeta(ep.Connection)
			}
		}
		jsonResp(w, s.app.Config)

	case http.MethodPut:
		var incoming contracts.AppConfig
		if err := json.NewDecoder(r.Body).Decode(&incoming); err != nil {
			jsonErr(w, 400, "invalid request body: "+err.Error())
			return
		}

		// Preserve SSH private keys from the current config.
		// The frontend no longer receives or sends ssh_private_key,
		// so we merge the incoming endpoints with the server-side private keys.
		for name, ep := range incoming.Endpoints {
			if ep.Connection == nil {
				continue
			}
			// Find if this endpoint already exists with a private key
			if existing, ok := s.app.Config.Endpoints[name]; ok {
				if existing.Connection != nil && existing.Connection.SSHPrivateKey != "" {
					ep.Connection.SSHPrivateKey = existing.Connection.SSHPrivateKey
				}
			}
		}

		if err := s.app.ConfigMgr.SavePut(&incoming); err != nil {
			jsonErr(w, 500, err.Error())
			return
		}

		// Update in-memory config and rebuild endpoint contexts
		s.app.Config.Endpoints = incoming.Endpoints
		if incoming.Auth != nil && incoming.Auth.Username != "" {
			s.app.Config.Auth.Username = incoming.Auth.Username
		}
		s.app.RefreshEndpoints()

		jsonResp(w, map[string]string{"status": "ok"})

	default:
		jsonErr(w, 405, "method not allowed")
	}
}

// POST /api/config/password
// Body: { "password": "new-password" }
func (s *Server) handlePassword(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonErr(w, 405, "method not allowed")
		return
	}

	var req struct {
		Password string `json:"password"`
	}
	if err := decodeJSON(r, &req); err != nil {
		jsonErr(w, 400, "invalid request body: "+err.Error())
		return
	}
	if req.Password == "" {
		jsonErr(w, 400, "password is required")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		jsonErr(w, 500, "failed to hash password: "+err.Error())
		return
	}

	// Update in-memory and persist
	if s.app.Config.Auth == nil {
		s.app.Config.Auth = &contracts.AuthConfig{}
	}
	s.app.Config.Auth.PasswordHash = string(hash)

	if err := s.app.ConfigMgr.SaveSystem(s.app.Config.BaseDataDir, s.app.Config.Auth); err != nil {
		jsonErr(w, 500, "failed to save password: "+err.Error())
		return
	}

	s.app.Logger.Info("password updated via web UI")
	jsonResp(w, map[string]string{"status": "ok"})
}

// GET /api/endpoints
func (s *Server) handleEndpoints(w http.ResponseWriter, r *http.Request) {
	eps := make([]*contracts.EndpointConfig, 0, len(s.app.Config.Endpoints))
	for _, ep := range s.app.Config.Endpoints {
		eps = append(eps, ep)
	}
	jsonResp(w, eps)
}

// GET /api/services?category=...&query=...
// POST /api/services (install)
func (s *Server) handleServices(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) {
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
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, services)

	case http.MethodPost:
		var req struct {
			Name   string                `json:"name"`
			Params []*contracts.ParamValue `json:"params"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonErr(w, 400, "invalid request body")
			return
		}
		id, err := ep.ServiceManager.Install(req.Name, req.Params, ep.Name)
		if err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, map[string]string{"container_id": id})

	default:
		jsonErr(w, 405, "method not allowed")
	}
}

// GET /api/services/{name}
// DELETE /api/services/{name}
// POST /api/services/{name}/status
// POST /api/services/{name}/restart
// POST /api/services/{name}/logs
// POST /api/services/{name}/render
func (s *Server) handleServiceByID(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) {
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
			jsonErr(w, 404, err.Error())
			return
		}
		// Also get status
		status, _ := ep.ServiceManager.Status(name)
		jsonResp(w, map[string]interface{}{
			"definition": svc,
			"status":     status,
		})

	case r.Method == http.MethodDelete && action == "":
		if err := ep.ServiceManager.Uninstall(name); err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, map[string]string{"status": "ok"})

	case r.Method == http.MethodPost && action == "status":
		status, err := ep.ServiceManager.Status(name)
		if err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, status)

	case r.Method == http.MethodPost && action == "restart":
		if err := ep.ServiceManager.Restart(name); err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, map[string]string{"status": "ok"})

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
			jsonErr(w, 500, err.Error())
			return
		}
		for _, c := range containers {
			if c.Labels[contracts.ManagedServiceLabel] == name {
				logs, err := ep.Runtime.ContainerLogs(c.ID, tail)
				if err != nil {
					jsonErr(w, 500, err.Error())
					return
				}
				jsonResp(w, map[string]string{"logs": logs})
				return
			}
		}
		jsonErr(w, 404, "service not installed")

	case r.Method == http.MethodPost && action == "render":
		var req struct {
			Params []*contracts.ParamValue `json:"params"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonErr(w, 400, "invalid request")
			return
		}
		cfg, err := ep.ServiceManager.RenderConfig(name, req.Params)
		if err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, cfg)

	case r.Method == http.MethodPost && action == "params":
		params, err := ep.ParamStore.GetAll()
		if err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, params)

	case r.Method == http.MethodPut && action == "params":
		var pv contracts.ParamValue
		if err := json.NewDecoder(r.Body).Decode(&pv); err != nil {
			jsonErr(w, 400, "invalid request")
			return
		}
		if err := ep.ParamStore.Set(&pv); err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, map[string]string{"status": "ok"})

	default:
		jsonErr(w, 404, "not found")
	}
}

// GET /api/containers?all=true
func (s *Server) handleContainers(w http.ResponseWriter, r *http.Request, ep *endpoint.Context) {
	if r.Method != http.MethodGet {
		jsonErr(w, 405, "method not allowed")
		return
	}
	all := r.URL.Query().Get("all") == "true"
	containers, err := ep.Runtime.ContainerList(all)
	if err != nil {
		jsonErr(w, 500, err.Error())
		return
	}
	jsonResp(w, containers)
}

// GET /api/subscriptions
// POST /api/subscriptions
func (s *Server) handleSubscriptions(w http.ResponseWriter, r *http.Request) {
	subMgr := s.app.SubscriptionManager()
	if subMgr == nil {
		jsonErr(w, 500, "subscription manager not available")
		return
	}
	switch r.Method {
	case http.MethodGet:
		subs, err := subMgr.List()
		if err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, subs)
	case http.MethodPost:
		var req struct {
			Name string `json:"name"`
			URL  string `json:"url"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonErr(w, 400, "invalid request")
			return
		}
		if err := subMgr.Add(&contracts.Subscription{Name: req.Name, URL: req.URL, Enabled: true}); err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, map[string]string{"status": "ok"})
	default:
		jsonErr(w, 405, "method not allowed")
	}
}

// POST /api/subscriptions/{name}/sync
// DELETE /api/subscriptions/{name}
func (s *Server) handleSubscriptionByID(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimPrefix(r.URL.Path, "/api/subscriptions/")
	parts := strings.SplitN(name, "/", 2)
	name = parts[0]
	action := ""
	if len(parts) > 1 {
		action = parts[1]
	}

	subMgr := s.app.SubscriptionManager()
	if subMgr == nil {
		jsonErr(w, 500, "subscription manager not available")
		return
	}

	switch {
	case r.Method == http.MethodPost && action == "sync":
		if err := subMgr.Sync(name); err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, map[string]string{"status": "synced"})

	case r.Method == http.MethodDelete:
		if err := subMgr.Remove(name); err != nil {
			jsonErr(w, 500, err.Error())
			return
		}
		jsonResp(w, map[string]string{"status": "ok"})

	default:
		jsonErr(w, 405, "method not allowed")
	}
}

func (s *Server) Start(addr string) error {
	s.app.Logger.Info("starting backend API server", zap.String("addr", addr))
	return http.ListenAndServe(addr, s.Handler())
}


