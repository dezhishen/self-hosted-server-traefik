package server

import (
	"encoding/json"
	"net/http"

	"github.com/dezhishen/self-hosted-server-traefik/backend/logger"
)

// ============================================================
// ErrorCategory — 错误大类，用于前端分类处理
// ============================================================

type ErrorCategory string

const (
	CatValidation    ErrorCategory = "VALIDATION"     // 400 参数校验失败
	CatAuth          ErrorCategory = "AUTH"            // 401 认证失败
	CatNotFound      ErrorCategory = "NOT_FOUND"       // 404 资源不存在
	CatConflict      ErrorCategory = "CONFLICT"        // 409 状态冲突
	CatInfrastructure ErrorCategory = "INFRASTRUCTURE" // 502 基础设施错误
	CatInternal      ErrorCategory = "INTERNAL"        // 500 内部错误
)

// ============================================================
// ErrorCode — 细粒度错误码，前端据此注册 handler
// 满足 OCP: 新增错误码只需加一行常量，核心逻辑不变
// ============================================================

type ErrorCode string

// ——— VALIDATION (400) ———
const (
	ErrInvalidRequest   ErrorCode = "INVALID_REQUEST"
	ErrMissingField     ErrorCode = "MISSING_FIELD"
	ErrInvalidValue     ErrorCode = "INVALID_VALUE"
	ErrInvalidJSON      ErrorCode = "INVALID_JSON"
	ErrMethodNotAllowed ErrorCode = "METHOD_NOT_ALLOWED" // HTTP 405
)

// ——— AUTH (401) ———
const (
	ErrUnauthorized   ErrorCode = "UNAUTHORIZED"
	ErrForbidden      ErrorCode = "FORBIDDEN"
	ErrNoPasswordSet  ErrorCode = "NO_PASSWORD_SET"
)

// ——— NOT_FOUND (404) ———
const (
	ErrEndpointNotFound     ErrorCode = "ENDPOINT_NOT_FOUND"
	ErrServiceNotFound      ErrorCode = "SERVICE_NOT_FOUND"
	ErrSubscriptionNotFound ErrorCode = "SUBSCRIPTION_NOT_FOUND"
	ErrContainerNotFound    ErrorCode = "CONTAINER_NOT_FOUND"
	ErrSSHKeyNotFound       ErrorCode = "SSH_KEY_NOT_FOUND"
)

// ——— CONFLICT (409) ———
const (
	ErrAlreadyExists    ErrorCode = "ALREADY_EXISTS"
	ErrAlreadyInstalled ErrorCode = "ALREADY_INSTALLED"
)

// ——— INFRASTRUCTURE (502) ———
const (
	ErrDockerConnect      ErrorCode = "DOCKER_CONNECT_FAILED"
	ErrDockerOperation    ErrorCode = "DOCKER_OPERATION_FAILED"
	ErrSSHOperation       ErrorCode = "SSH_OPERATION_FAILED"
	ErrSubscriptionSync   ErrorCode = "SUBSCRIPTION_SYNC_FAILED"
)

// ——— INTERNAL (500) ———
const (
	ErrConfigSave      ErrorCode = "CONFIG_SAVE_FAILED"
	ErrPasswordHash    ErrorCode = "PASSWORD_HASH_FAILED"
	ErrSessionCreate   ErrorCode = "SESSION_CREATE_FAILED"
	ErrInternal        ErrorCode = "INTERNAL_ERROR"
)

// ============================================================
// APIError — 标准化的 API 错误结构
// 满足 OCP: 核心类型不变，新增错误码只需加常量
// ============================================================

// APIError 是返回给前端的标准错误。
// Code:  机器可读的错误码，前端据此注册 handler
// Category: 错误大类，前端用于分类 fallback
// Message: 人类可读的错误描述
// Details: 动态字段，每个 ErrorCode 可携带不同的上下文
//
// Cause 和 HTTPCode 为内部字段，不序列化给前端。
type APIError struct {
	Code     ErrorCode       `json:"code"`
	Category ErrorCategory   `json:"category"`
	Message  string          `json:"message"`
	Details  interface{}     `json:"details,omitempty"`

	HTTPCode int   `json:"-"` // HTTP 状态码
	Cause    error `json:"-"` // 原始 error，仅日志使用
}

// WithDetail 设置额外上下文，满足 OCP：无需修改结构体即可扩展。
func (e *APIError) WithDetail(key string, val interface{}) *APIError {
	if e.Details == nil {
		e.Details = map[string]interface{}{}
	}
	if m, ok := e.Details.(map[string]interface{}); ok {
		m[key] = val
	}
	return e
}

// WithCause 绑定原始错误（仅用于日志，不暴露给前端）。
func (e *APIError) WithCause(err error) *APIError {
	e.Cause = err
	return e
}

// ============================================================
// 工厂函数 — 每个分类一个，自动设置 HTTPCode 和 Category
// ============================================================

// NewAPIError 是底层构造函数，公开给 MethodNotAllowed 等特殊场景使用。
func NewAPIError(httpCode int, cat ErrorCategory, code ErrorCode, msg string) *APIError {
	return &APIError{
		Code: code, Category: cat, Message: msg, HTTPCode: httpCode,
	}
}

func ValidationError(code ErrorCode, msg string) *APIError {
	return &APIError{
		Code: code, Category: CatValidation, Message: msg, HTTPCode: 400,
	}
}

func AuthError(code ErrorCode, msg string) *APIError {
	return &APIError{
		Code: code, Category: CatAuth, Message: msg, HTTPCode: 401,
	}
}

func NotFoundError(code ErrorCode, msg string) *APIError {
	return &APIError{
		Code: code, Category: CatNotFound, Message: msg, HTTPCode: 404,
	}
}

func ConflictError(code ErrorCode, msg string) *APIError {
	return &APIError{
		Code: code, Category: CatConflict, Message: msg, HTTPCode: 409,
	}
}

func InfrastructureError(code ErrorCode, msg string) *APIError {
	return &APIError{
		Code: code, Category: CatInfrastructure, Message: msg, HTTPCode: 502,
	}
}

func InternalError(code ErrorCode, msg string) *APIError {
	return &APIError{
		Code: code, Category: CatInternal, Message: msg, HTTPCode: 500,
	}
}

// MethodNotAllowed 是 405 快捷方式。
func MethodNotAllowed() *APIError {
	return NewAPIError(405, CatValidation, ErrMethodNotAllowed, "method not allowed")
}

// ============================================================
// writeError — 统一写入 JSON 错误响应 + 日志
// ============================================================

func (s *Server) writeError(w http.ResponseWriter, apiErr *APIError) {
	if apiErr.Cause != nil {
		s.app.Logger.Warn("api error",
			logger.String("code", string(apiErr.Code)),
			logger.String("category", string(apiErr.Category)),
			logger.Int("http_status", apiErr.HTTPCode),
			logger.Error(apiErr.Cause),
		)
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(apiErr.HTTPCode)
	json.NewEncoder(w).Encode(map[string]*APIError{"error": apiErr})
}
