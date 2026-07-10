import axios from 'axios'
import { ElMessage } from 'element-plus'

const client = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

client.interceptors.request.use(
  (config) => {
    const store = (window as any).__pinia?.state?.value?.currentRemote
    if (store?.current) {
      config.headers['X-Remote-Name'] = store.current
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
