import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import client, { setCurrentRemote } from '@/api/client'

export interface RemoteHost {
  name: string
  type: string
  address: string
  engine: string
  default: boolean
}

const STORAGE_KEY = 'selfhosted_remote'

export const useCurrentRemote = defineStore('currentRemote', () => {
  const current = ref<string>('')
  const remotes = ref<RemoteHost[]>([])
  const loading = ref(false)
  const initialized = ref(false)

  // Sync the module-level _currentRemote whenever the store's current value changes.
  // This ensures the axios interceptor always has the latest value without
  // relying on window.__pinia or circular imports.
  watch(current, (val) => {
    if (val) setCurrentRemote(val)
  })

  async function fetchRemotes() {
    loading.value = true
    try {
      const res = await client.get('/endpoints')
      remotes.value = res.data

      // 1. Try localStorage first
      const saved = localStorage.getItem(STORAGE_KEY)
      if (saved && remotes.value.some(r => r.name === saved)) {
        current.value = saved
      } else {
        // 2. Fall back to default
        const def = remotes.value.find(r => r.default)
        current.value = def?.name || (remotes.value.length > 0 ? remotes.value[0].name : '')
      }
    } finally {
      loading.value = false
      initialized.value = true
    }
  }

  function select(name: string) {
    current.value = name
    localStorage.setItem(STORAGE_KEY, name)
  }

  const currentHost = computed(() => remotes.value.find(r => r.name === current.value))
  const hasRemotes = computed(() => remotes.value.length > 0)
  const selected = computed(() => current.value !== '')

  return { current, remotes, loading, initialized, fetchRemotes, select, currentHost, hasRemotes, selected }
})