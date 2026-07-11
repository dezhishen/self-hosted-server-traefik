import axios from 'axios'
import { ElMessage } from 'element-plus'

const client = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// Module-level cache for the current remote name.
// Set by the Pinia store via setCurrentRemote() to avoid circular imports.
let _currentRemote = ''

export function setCurrentRemote(name: string) {
  _currentRemote = name
}

// Module-level cache for the auth token.
// Set by the Pinia store via setAuthToken() to avoid circular imports.
let _authToken: string | null = null

export function setAuthToken(token: string | null) {
  _authToken = token
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
    if (error.response?.status === 401) {
      // Token expired or invalid — clear auth state.
      // Import dynamically to avoid circular dependency.
      setAuthToken(null)
      localStorage.removeItem('selfhosted_auth_token')
      localStorage.removeItem('selfhosted_auth_username')
      // Redirect to login if not already there
      if (window.location.pathname !== '/login') {
        window.location.href = '/login'
      }
    }
    const message = error.response?.data?.error || error.message || 'Request failed'
    ElMessage.error(message)
    return Promise.reject(error)
  }
)

export default client
