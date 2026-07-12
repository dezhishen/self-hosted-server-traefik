import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import router from '@/router'
import client, { setAuthToken } from '@/api/client'

const TOKEN_KEY = 'selfhosted_auth_token'
const USERNAME_KEY = 'selfhosted_auth_username'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(null)
  const username = ref<string | null>(null)
  const loading = ref(false)

  const authenticated = computed(() => token.value !== null)

  // Sync the module-level token for the axios interceptor
  watch(token, (val) => {
    setAuthToken(val)
  })

  async function login(user: string, pass: string) {
    loading.value = true
    try {
      const res = await client.post('/auth/login', {
        username: user,
        password: pass
      })
      token.value = res.data.token
      username.value = res.data.username
      localStorage.setItem(TOKEN_KEY, res.data.token)
      localStorage.setItem(USERNAME_KEY, res.data.username)
    } finally {
      loading.value = false
    }
  }

  async function logout() {
    try {
      await client.post('/auth/logout')
    } catch {
      // Ignore errors — we're clearing state regardless
    }
    token.value = null
    username.value = null
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(USERNAME_KEY)
    router.push('/login')
  }

  function initFromStorage() {
    const savedToken = localStorage.getItem(TOKEN_KEY)
    const savedUsername = localStorage.getItem(USERNAME_KEY)
    if (savedToken && savedUsername) {
      token.value = savedToken
      username.value = savedUsername
    }
  }

  return { token, username, loading, authenticated, login, logout, initFromStorage }
})
