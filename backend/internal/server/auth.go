package server

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"strings"
	"sync"
)

// contextKey is used for storing auth info in request context.
type contextKey string

const (
	authHeader     = "Authorization"
	authScheme     = "Bearer "
	ctxAuthUserKey = contextKey("auth_username")
)

// sessionManager manages bearer token sessions in-memory.
type sessionManager struct {
	mu       sync.RWMutex
	sessions map[string]string // token -> username
}

func newSessionManager() *sessionManager {
	return &sessionManager{
		sessions: make(map[string]string),
	}
}

// generateToken produces a cryptographically random 32-byte hex string.
func generateToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

// CreateSession creates a new session for the given username and returns the token.
func (sm *sessionManager) CreateSession(username string) (string, error) {
	token, err := generateToken()
	if err != nil {
		return "", err
	}
	sm.mu.Lock()
	sm.sessions[token] = username
	sm.mu.Unlock()
	return token, nil
}

// ValidateSession checks if a token is valid and returns the associated username.
func (sm *sessionManager) ValidateSession(token string) (string, bool) {
	sm.mu.RLock()
	username, ok := sm.sessions[token]
	sm.mu.RUnlock()
	return username, ok
}

// RevokeSession removes a session by token.
func (sm *sessionManager) RevokeSession(token string) {
	sm.mu.Lock()
	delete(sm.sessions, token)
	sm.mu.Unlock()
}

// extractBearerToken extracts the Bearer token from the Authorization header.
func extractBearerToken(r *http.Request) (string, bool) {
	auth := r.Header.Get(authHeader)
	if !strings.HasPrefix(auth, authScheme) {
		return "", false
	}
	return strings.TrimPrefix(auth, authScheme), true
}

// publicRoutes lists path prefixes that don't require authentication.
var publicRoutes = []string{
	"/api/auth/",
	"/api/health",
	"/api/endpoints",
}

// isPublicRoute checks if a request path is a public route.
func isPublicRoute(path string) bool {
	for _, prefix := range publicRoutes {
		if strings.HasPrefix(path, prefix) {
			return true
		}
	}
	return false
}
