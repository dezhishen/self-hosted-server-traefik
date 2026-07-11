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

client.interceptors.request.use(
  (config) => {
    if (_currentRemote) {
      config.headers['X-Remote-Name'] = _currentRemote
    }
    return config
  },
  (error) => Promise.reject(error)
)

client.interceptors.response.use(
  (response) => response,
  (error) => {
    const message = error.response?.data?.error || error.message || 'Request failed'
    ElMessage.error(message)
    return Promise.reject(error)
  }
)

export default client
