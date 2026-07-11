<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { User, Lock } from '@element-plus/icons-vue'

const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()

const username = ref('')
const password = ref('')
const errorMsg = ref('')
const loading = ref(false)

async function handleLogin() {
  if (!username.value || !password.value) {
    errorMsg.value = t('auth.required')
    return
  }
  errorMsg.value = ''
  loading.value = true
  try {
    await authStore.login(username.value, password.value)
    router.push('/')
  } catch (err: any) {
    errorMsg.value = err.response?.data?.error || err.message || t('auth.login_failed')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-container">
    <div class="login-card">
      <div class="login-header">
        <img src="@/assets/logo.svg" alt="SelfHosted" class="login-logo" />
        <h1 class="login-title">SelfHosted</h1>
        <p class="login-desc">{{ t('app.desc') }}</p>
      </div>

      <el-alert
        v-if="errorMsg"
        type="error"
        :title="errorMsg"
        show-icon
        closable
        class="mb-4"
        @close="errorMsg = ''"
      />

      <el-form @submit.prevent="handleLogin" label-position="top">
        <el-form-item :label="t('auth.username')">
          <el-input
            v-model="username"
            :placeholder="t('auth.username_placeholder')"
            :prefix-icon="User"
            size="large"
            autocomplete="username"
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-form-item :label="t('auth.password')">
          <el-input
            v-model="password"
            type="password"
            :placeholder="t('auth.password_placeholder')"
            :prefix-icon="Lock"
            size="large"
            show-password
            autocomplete="current-password"
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-form-item>
          <el-button
            type="primary"
            size="large"
            class="w-full"
            :loading="loading"
            @click="handleLogin"
          >
            {{ loading ? t('auth.signing_in') : t('auth.sign_in') }}
          </el-button>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>

<style scoped>
.login-container {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background-color: var(--bg-secondary, #f0f2f5);
}

.login-card {
  width: 100%;
  max-width: 400px;
  padding: 40px 32px 32px;
  background: var(--bg-card, #ffffff);
  border-radius: 8px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
  margin: 16px;
}

.login-header {
  text-align: center;
  margin-bottom: 32px;
}

.login-logo {
  width: 64px;
  height: 64px;
  margin-bottom: 12px;
}

.login-title {
  font-size: 24px;
  font-weight: 600;
  color: var(--text-primary, #303133);
  margin: 0 0 4px;
}

.login-desc {
  font-size: 14px;
  color: var(--text-secondary, #606266);
  margin: 0;
}
</style>
