import axios from 'axios'
import { errorHandler, extractAppError } from './errors'

const client = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// Module-level caches
let _currentRemote = ''
let _authToken: string | null = null

export function setCurrentRemote(name: string) {
  _currentRemote = name
}

export function setAuthToken(token: string | null) {
  _authToken = token
}

function clearAuth() {
  setAuthToken(null)
  localStorage.removeItem('selfhosted_auth_token')
  localStorage.removeItem('selfhosted_auth_username')
}

client.interceptors.request.use(
  (config) => {
    if (_currentRemote) {
      config.headers['X-Remote-Name'] = _currentRemote
    }
    if (_authToken) {
      config.headers['Authorization'] = `Bearer ${_authToken}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

client.interceptors.response.use(
  (response) => response,
  (error) => {
    const appError = extractAppError(error)

    // 401 → 清除登录态，跳转登录
    if (error.response?.status === 401) {
      clearAuth()
      // Use Vue Router if available, fallback to window.location
      try {
        // Dynamic import to avoid circular dependency
        const router = (window as any).__vue_router
        if (router) {
          router.push('/login')
        } else {
          window.location.href = '/login'
        }
      } catch {
        window.location.href = '/login'
      }
      return Promise.reject(appError)
    }

    // 其他错误 → 走注册链处理（由视图决定如何展示）
    errorHandler.handle(appError)
    return Promise.reject(appError)
  }
)

export default client
