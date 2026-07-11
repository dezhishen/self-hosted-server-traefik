import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import 'element-plus/theme-chalk/dark/css-vars.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'
import { errorHandler, ErrorCategory } from '@/api/errors'
import i18n from './i18n'
import './styles/index.css'

const app = createApp(App)

for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component)
}

const pinia = createPinia()
app.use(pinia)
app.use(router)
app.use(ElementPlus)
app.use(i18n)

// Initialize auth from localStorage before mounting
const authStore = useAuthStore()
authStore.initFromStorage()

// 注册全局错误处理 handler
// 1. INFRASTRUCTURE 类错误 — 提示检查 Docker/SSH 连接
errorHandler.onCategory(ErrorCategory.INFRASTRUCTURE, (err) => {
  ElMessage.error(err.message)
})

// 2. 全局兜底
errorHandler.setDefault((err) => {
  ElMessage.error(err.message)
})

app.mount('#app')
