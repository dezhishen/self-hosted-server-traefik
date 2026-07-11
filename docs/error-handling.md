# 错误处理设计

## 目标

在整个系统中提供一致的错误处理体验：后端返回结构化错误，前端通过注册链精确控制展示。

---

## 后端架构

### 三层错误结构

```
HTTP status  →  传输协议层 (400/401/404/409/502/500)
error.code   →  机器可读标识符（如 "DOCKER_CONNECT_FAILED"）
error.message →  人类可读描述
error.details →  [可选] 每个 code 自定的动态字段
```

### ErrorCategory

| Category | HTTP Status | 含义 |
|----------|-------------|------|
| VALIDATION | 400 | 请求参数校验失败 |
| AUTH | 401 | 未登录或 token 无效 |
| NOT_FOUND | 404 | 资源不存在 |
| CONFLICT | 409 | 资源冲突（已存在） |
| INFRASTRUCTURE | 502 | 基础设施错误（Docker/SSH 连接失败） |
| INTERNAL | 500 | 服务器内部错误 |

### APIError 类型

```go
type APIError struct {
    Code     ErrorCode        `json:"code"`
    Category ErrorCategory    `json:"category"`
    Message  string           `json:"message"`
    Details  map[string]any   `json:"details,omitempty"`
}
```

### 工厂函数

每个 Category 对应一个工厂函数：

| 函数 | 对应 Category |
|------|---------------|
| `ValidationError(code, msg)` | VALIDATION |
| `AuthError(code, msg)` | AUTH |
| `NotFoundError(code, msg)` | NOT_FOUND |
| `ConflictError(code, msg)` | CONFLICT |
| `InfrastructureError(code, msg)` | INFRASTRUCTURE |
| `InternalError(code, msg)` | INTERNAL |
| `MethodNotAllowed(allowed ...string)` | VALIDATION |

所有工厂函数返回 `*APIError`。

### WithDetail 链式方法

```go
InfrastructureError(ErrDockerConnectFailed, "Docker 连接失败").
    WithDetail("endpoint", endpointName).
    WithDetail("hint", "请检查 Docker 是否已启动")
```

### Handler 签名转变

**之前**：handler 直接写入 `http.ResponseWriter`

```go
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request)
```

**之后**：handler 返回 `*APIError`，写入由 `handle()` 适配器统一完成

```go
type apiHandler = func(http.ResponseWriter, *http.Request) *APIError

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) *APIError {
    return nil // 或 return InternalError(...)
}
```

### 适配器模式

```go
// handle 将 apiHandler 适配为标准 http.HandlerFunc
func (s *Server) handle(h apiHandler) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        if err := h(w, r); err != nil {
            writeError(w, r, err)
        }
    }
}
```

`writeError` 统一完成：
- 设置 HTTP status code
- 写入 JSON 响应体
- 记录结构化日志（含 code、category、details）

### 路由注册

```go
// 无需认证
s.mux.Handle("GET /api/health", s.withLogging(s.handle(s.handleHealth)))

// 需认证
s.mux.Handle("POST /api/restart/{name}", s.withLogging(s.handle(s.withAuth(s.handleRestart))))

// 需认证 + 自动解析端点
s.mux.Handle("GET /api/services", s.withLogging(s.handleWithEndpoint(s.withAuth(s.handleServices))))
```

---

## 前端架构

### 数据流

```
Axios response
    ↓
Response interceptor
    ├─ 401 → clearAuth() + 跳转 /login
    └─ 其他 → errorHandler.handle(appError) + Promise.reject(appError)
                    ↓
            ErrorHandlerRegistry
                ├─ on(code, handler)     → 精确匹配
                ├─ onCategory(handler)   → category 匹配
                └─ setDefault(handler)   → 全局兜底
```

### AppError 结构

```typescript
interface AppError {
  code: string
  category: string
  message: string
  details?: Record<string, unknown>
}
```

### extractAppError

从 Axios error 中提取 AppError，处理三种情况：

1. **新格式**：`response.data.error.code` 存在 → 直接返回
2. **旧格式**：`response.data.error` 是 string → 封装为 `{code: "UNKNOWN", category: "INTERNAL"}`
3. **网络错误**：无 response → 封装为 `{code: "NETWORK_ERROR", category: "INFRASTRUCTURE"}`

### ErrorHandlerRegistry

链式处理顺序：

1. **精确匹配 error.code** — 如 `on("DOCKER_CONNECT_FAILED", handler)`
2. **category 匹配** — 如 `onCategory("INFRASTRUCTURE", handler)`
3. **全局兜底** — `setDefault(handler)`

每个 handler 返回 `true` 或 `undefined` 终止链，返回 `false` 继续 fallback。

### 全局 Handler（在 main.ts 注册）

```typescript
// 1. INFRASTRUCTURE 类错误 — 提示检查连接
errorHandler.onCategory(ErrorCategory.INFRASTRUCTURE, (err) => {
  ElMessage.error(err.message)
})

// 2. 全局兜底
errorHandler.setDefault((err) => {
  ElMessage.error(err.message)
})
```

### useRequest Composable

```typescript
function useRequest<T>(
  request: () => Promise<T>,
  options?: {
    onError?: (err: AppError) => void  // 视图自定义处理，跳过注册链
    onSuccess?: (data: T) => void
  }
): { loading, error, execute }
```

---

## 视图错误处理模式

### 操作型 handler（restart/uninstall/sync）

```typescript
async function handleRestart(name: string) {
  try {
    await restartService(name)
    ElMessage.success(t('common.success'))
  } catch {
    // 错误由 errorHandler 注册链处理
  }
}
```

### 数据获取（fetch/list）

```typescript
async function fetchServices() {
  loading.value = true
  try {
    const res = await listServices()
    services.value = res.data
  } finally {
    loading.value = false
  }
}
```

### 自定义处理（Login）

```typescript
try {
  await authStore.login(username.value, password.value)
  router.push('/')
} catch (err: any) {
  errorMsg.value = err.response?.data?.error || err.message
}
```

---

## 错误码清单

| Code | Category | HTTP | 说明 |
|------|----------|------|------|
| VALIDATION_ERROR | VALIDATION | 400 | 通用校验失败 |
| REQUIRED_FIELD | VALIDATION | 400 | 缺少必填字段 |
| INVALID_FORMAT | VALIDATION | 400 | 格式错误 |
| OUT_OF_RANGE | VALIDATION | 400 | 值超出范围 |
| METHOD_NOT_ALLOWED | VALIDATION | 400 | HTTP 方法不允许 |
| AUTH_REQUIRED | AUTH | 401 | 未登录 |
| AUTH_EXPIRED | AUTH | 401 | Token 过期 |
| AUTH_INVALID | AUTH | 401 | Token 无效 |
| AUTH_WRONG_CREDENTIALS | AUTH | 401 | 用户名或密码错误 |
| NOT_FOUND | NOT_FOUND | 404 | 通用不存在 |
| SERVICE_NOT_FOUND | NOT_FOUND | 404 | 服务不存在 |
| ENDPOINT_NOT_FOUND | NOT_FOUND | 404 | 端点不存在 |
| SUBSCRIPTION_NOT_FOUND | NOT_FOUND | 404 | 订阅不存在 |
| ALREADY_EXISTS | CONFLICT | 409 | 资源已存在 |
| DOCKER_CONNECT_FAILED | INFRASTRUCTURE | 502 | Docker 连接失败 |
| DOCKER_CONTAINER_FAILED | INFRASTRUCTURE | 502 | 容器操作失败 |
| SSH_CONNECT_FAILED | INFRASTRUCTURE | 502 | SSH 连接失败 |
| SSH_KEYGEN_FAILED | INFRASTRUCTURE | 502 | SSH 密钥生成失败 |
| SSH_KEY_IMPORT_FAILED | INFRASTRUCTURE | 502 | SSH 密钥导入失败 |
| REMOTE_CONNECT_FAILED | INFRASTRUCTURE | 502 | 远程连接失败 |
| GIT_OPERATION_FAILED | INFRASTRUCTURE | 502 | Git 操作失败 |
| SUBS_SYNC_FAILED | INFRASTRUCTURE | 502 | 订阅同步失败 |
| INTERNAL_ERROR | INTERNAL | 500 | 通用内部错误 |
| INVALID_CONFIG | INTERNAL | 500 | 配置无效 |
| DATA_CORRUPTION | INTERNAL | 500 | 数据损坏 |
| UNKNOWN | INTERNAL | 500 | 未知错误 |

---

## OCP 扩展方式

**新增错误码**：在 `errors.go` 的 `ErrorCode` const 块加一行：

```go
const MyNewCode ErrorCode = "MY_NEW_CODE"
```

**新增 Category**：加 `const MyCategory ErrorCategory = "MY_CATEGORY"`，加 Category HTTP status 映射，加工厂函数。

**新增前端 handler**：

```typescript
errorHandler.on(ErrorCode.DOCKER_CONNECT_FAILED, (err) => {
  ElMessageBox.alert('请检查 Docker 是否已启动', '连接失败')
})
```
