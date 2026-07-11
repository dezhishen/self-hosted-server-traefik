import { ref } from 'vue'
import { errorHandler, extractAppError } from '@/api/errors'
import type { AppError } from '@/api/errors'

/**
 * useRequest — 统一请求封装。
 *
 * 职责：
 * - 管理 loading/error 状态
 * - 提供 onSuccess 回调
 * - 通过 onError 选项支持视图自定义错误处理（跳过全局注册链）
 * - 无 onError 时自动走 errorHandler 注册链
 *
 * @example
 * ```ts
 * // 默认：错误走全局注册链
 * const { execute: restart, loading } = useRequest(() => restartService(name))
 *
 * // 自定义：错误在视图内处理（不弹 toast）
 * const { execute: login } = useRequest(doLogin, {
 *   onError: (err) => { errorMsg.value = err.message }
 * })
 * ```
 */
export function useRequest<T>(
  request: () => Promise<T>,
  options?: {
    onError?: (err: AppError) => void
    onSuccess?: (data: T) => void
  }
) {
  const loading = ref(false)
  const error = ref<AppError | null>(null)

  async function execute(): Promise<T | undefined> {
    loading.value = true
    error.value = null
    try {
      const result = await request()
      options?.onSuccess?.(result)
      return result
    } catch (e) {
      const appError = extractAppError(e)
      error.value = appError

      if (options?.onError) {
        // 视图自定义处理 → 跳过全局注册链
        options.onError(appError)
      } else {
        // 无自定义处理 → 走全局注册链
        errorHandler.handle(appError)
      }
    } finally {
      loading.value = false
    }
  }

  return { loading, error, execute }
}
