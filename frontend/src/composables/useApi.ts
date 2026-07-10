import { ref, computed } from 'vue'
import type { Ref } from 'vue'

export function useApi<T>(apiFn: (...args: any[]) => Promise<{ data: T }>) {
  const data: Ref<T | null> = ref(null)
  const loading: Ref<boolean> = ref(false)
  const error: Ref<string | null> = ref(null)

  async function execute(...args: any[]): Promise<T | null> {
    loading.value = true
    error.value = null
    try {
      const response = await apiFn(...args)
      data.value = response.data
      return response.data
    } catch (e: any) {
      error.value = e.message || 'An error occurred'
      return null
    } finally {
      loading.value = false
    }
  }

  const hasData = computed(() => data.value !== null)
  const isError = computed(() => error.value !== null)

  return {
    data,
    loading,
    error,
    execute,
    hasData,
    isError
  }
}
