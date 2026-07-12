<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { getConfig, changePassword } from '@/api/config'
import type { AppConfig } from '@/api/config'
import SdCard from '@/components/SdCard.vue'
import { ElMessage } from 'element-plus'

const { t } = useI18n()

const config = ref<AppConfig | null>(null)
const loading = ref(false)
const saving = ref(false)
const passwordSaving = ref(false)
const newPassword = ref('')
const confirmPassword = ref('')

async function fetchConfig() {
  loading.value = true
  try {
    const res = await getConfig()
    config.value = res.data
  } finally {
    loading.value = false
  }
}

async function handleSave() {
  if (!config.value) return
  saving.value = true
  try {
    const { updateConfig } = await import('@/api/config')
    await updateConfig(config.value)
    ElMessage.success(t('common.success'))
  } finally {
    saving.value = false
  }
}

async function handlePasswordSave() {
  if (!newPassword.value) {
    ElMessage.warning(t('settings.msg_password_required'))
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    ElMessage.warning(t('settings.password_mismatch'))
    return
  }
  passwordSaving.value = true
  try {
    await changePassword(newPassword.value)
    ElMessage.success(t('settings.password_updated'))
    newPassword.value = ''
    confirmPassword.value = ''
  } finally {
    passwordSaving.value = false
  }
}

onMounted(fetchConfig)
</script>

<template>
  <div class="page-header flex items-center justify-between flex-wrap gap-2">
    <h2>{{ t('settings.title') }}</h2>
  </div>

  <div v-loading="loading">
    <el-row :gutter="20">
      <el-col :xs="24" :md="16">
        <!-- Config Path & Username -->
        <SdCard>
          <template #header>
            <span class="font-semibold">{{ t('settings.title') }}</span>
          </template>
          <el-form label-position="top" v-if="config">
            <el-form-item :label="t('settings.config_path')">
              <el-input :model-value="config.base_data_dir" disabled />
            </el-form-item>
            <el-form-item :label="t('auth.username')">
              <el-input v-model="config.auth!.username" :placeholder="t('auth.username_placeholder')" />
            </el-form-item>
            <el-button type="primary" :loading="saving" @click="handleSave">
              {{ t('settings.save') }}
            </el-button>
          </el-form>
        </SdCard>

        <!-- Change Password -->
        <SdCard class="mt-4">
          <template #header>
            <span class="font-semibold">{{ t('settings.password') }}</span>
          </template>
          <el-form label-position="top">
            <el-form-item :label="t('settings.new_password')">
              <el-input
                v-model="newPassword"
                type="password"
                :placeholder="t('settings.new_password')"
                show-password
              />
            </el-form-item>
            <el-form-item :label="t('settings.confirm_password')">
              <el-input
                v-model="confirmPassword"
                type="password"
                :placeholder="t('settings.confirm_password')"
                show-password
              />
            </el-form-item>
            <el-button type="primary" :loading="passwordSaving" @click="handlePasswordSave">
              {{ t('settings.update_password') }}
            </el-button>
          </el-form>
        </SdCard>
      </el-col>
    </el-row>
  </div>
</template>
