/**
 * 标准化的 API 错误类型。
 * 与后端 errors.go 的 APIError 结构保持一致。
 */
/** 错误分类常量，与后端 ErrorCategory 保持一致 */
export const ErrorCategory = {
  VALIDATION: 'VALIDATION',
  AUTH: 'AUTH',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  INFRASTRUCTURE: 'INFRASTRUCTURE',
  INTERNAL: 'INTERNAL'
} as const

export type ErrorCategory = (typeof ErrorCategory)[keyof typeof ErrorCategory]

export interface AppError {
  code: string
  category: string
  message: string
  details?: Record<string, unknown>
}

/** Axios 错误响应体中提取 AppError */
export function extractAppError(err: unknown): AppError {
  const axiosErr = err as any
  const body = axiosErr?.response?.data
  if (body?.error?.code) {
    return body.error as AppError
  }
  // 后端可能返回旧格式 {"error": "message"}
  if (body?.error && typeof body.error === 'string') {
    return { code: 'UNKNOWN', category: 'INTERNAL', message: body.error }
  }
  // 网络错误（无响应）
  if (!axiosErr?.response) {
    return {
      code: 'NETWORK_ERROR',
      category: 'INFRASTRUCTURE',
      message: axiosErr?.message || '无法连接到服务器'
    }
  }
  return { code: 'UNKNOWN', category: 'INTERNAL', message: '未知错误' }
}

/**
 * 错误处理函数。
 * 返回 true 或 void 表示已处理（终止链），
 * 返回 false 表示继续 fallback 到下一级。
 */
type ErrorHandler = (err: AppError) => boolean | void

/**
 * ErrorHandlerRegistry — 基于 error code 注册委托方法的错误处理中心。
 *
 * 处理链：
 *   精确匹配 error.code → category 匹配 → 全局兜底
 *
 * 满足 OCP：新增错误 handler 只需注册，核心逻辑不变。
 */
class ErrorHandlerRegistry {
  private handlers = new Map<string, ErrorHandler>()
  private categoryHandlers = new Map<string, ErrorHandler>()
  private defaultHandler: ErrorHandler = (err) => {
    console.warn('[unhandled api error]', err.code, err.category, err.message)
  }

  /** 注册精确 error.code 的 handler */
  on(code: string, handler: ErrorHandler): void {
    this.handlers.set(code, handler)
  }

  /** 注册按 category 兜底的 handler */
  onCategory(category: string, handler: ErrorHandler): void {
    this.categoryHandlers.set(category, handler)
  }

  /** 移除精确 error.code 的 handler（组件卸载时清理） */
  off(code: string): void {
    this.handlers.delete(code)
  }

  /** 设置全局兜底 handler */
  setDefault(handler: ErrorHandler): void {
    this.defaultHandler = handler
  }

  /** 执行错误处理链 */
  async handle(err: AppError): Promise<void> {
    // 1. 精确匹配 error.code
    if (this.handlers.has(err.code)) {
      const result = this.handlers.get(err.code)!(err)
      if (result !== false) return
    }
    // 2. category 匹配
    if (this.categoryHandlers.has(err.category)) {
      const result = this.categoryHandlers.get(err.category)!(err)
      if (result !== false) return
    }
    // 3. 全局兜底
    this.defaultHandler(err)
  }
}

/** 全局单例 */
export const errorHandler = new ErrorHandlerRegistry()
