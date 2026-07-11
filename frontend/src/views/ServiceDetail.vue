<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { getService, uninstallService, restartService, getServiceLogs } from '@/api/services'
import type { ServiceDetail } from '@/api/services'
import SdStatus from '@/components/SdStatus.vue'
import SdCard from '@/components/SdCard.vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const serviceName = route.params.name as string

const detail = ref<ServiceDetail | null>(null)
const logs = ref('')
const loading = ref(false)
const logLoading = ref(false)
const activeTab = ref('info')

const service = computed(() => detail.value?.definition)
const serviceStatus = computed(() => detail.value?.status || '')
const container = computed(() => service.value?.container)

async function fetchService() {
  loading.value = true
  try {
    const res = await getService(serviceName)
    detail.value = res.data
  } finally {
    loading.value = false
  }
}

async function fetchLogs() {
  logLoading.value = true
  try {
    const res = await getServiceLogs(serviceName, 200)
    logs.value = res.data.logs
  } finally {
    logLoading.value = false
  }
}

function handleTabChange(tab: string) {
  if (tab === 'logs' && !logs.value) {
    fetchLogs()
  }
}

async function handleRestart() {
  try {
    await restartService(serviceName)
    ElMessage.success(t('common.success'))
  } catch {
  }
}

async function handleUninstall() {
  try {
    await ElMessageBox.confirm(
      t('services.uninstall') + ` "${serviceName}"?`,
      t('common.confirm'),
      { confirmButtonText: t('services.uninstall'), cancelButtonText: t('common.close'), type: 'warning' }
    )
    await uninstallService(serviceName)
    ElMessage.success(t('common.success'))
    router.push('/services')
  } catch {
  }
}

onMounted(fetchService)
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <div class="flex items-center gap-3">
      <h2 class="m-0">{{ serviceName }}</h2>
      <SdStatus :status="serviceStatus" />
    </div>
    <div class="flex gap-2 flex-wrap">
      <el-button type="primary" size="small" @click="handleRestart">{{ t('services.restart') }}</el-button>
      <el-button type="danger" size="small" @click="handleUninstall">{{ t('services.uninstall') }}</el-button>
      <el-button size="small" @click="router.push('/services')">{{ t('common.back') }}</el-button>
    </div>
  </div>

  <div v-loading="loading">
    <el-tabs v-model="activeTab" @tab-change="handleTabChange">
      <el-tab-pane :label="t('services.detail')" name="info">
        <SdCard>
          <template #header>
            <span class="font-semibold">{{ t('services.detail') }}</span>
          </template>
          <el-descriptions :column="1" border>
            <el-descriptions-item :label="t('common.detail') || 'Name'">{{ service?.name || '-' }}</el-descriptions-item>
            <el-descriptions-item :label="t('common.desc')">{{ service?.description || '-' }}</el-descriptions-item>
            <el-descriptions-item :label="t('common.category')">{{ service?.category || '-' }}</el-descriptions-item>
            <el-descriptions-item label="Image">{{ service?.image || '-' }}</el-descriptions-item>
          </el-descriptions>
        </SdCard>

        <el-row :gutter="[20, 16]" class="mt-4">
          <el-col :xs="24" :md="12">
            <SdCard>
              <template #header>
                <span class="font-semibold">Ports</span>
              </template>
              <div v-if="container?.ports?.length">
                <el-tag v-for="port in container.ports" :key="`${port.host_port}-${port.container_port}`" class="mr-2 mb-2">
                  {{ port.host_port }}:{{ port.container_port }}/{{ port.protocol || 'tcp' }}
                </el-tag>
              </div>
              <el-empty v-else :description="t('common.no_data')" :image-size="60" />
            </SdCard>
          </el-col>
          <el-col :xs="24" :md="12">
            <SdCard>
              <template #header>
                <span class="font-semibold">Volumes</span>
              </template>
              <div v-if="container?.volumes?.length">
                <div v-for="vol in container.volumes" :key="vol.source" class="text-sm py-1 font-mono">
                  {{ vol.source }}:{{ vol.target }}
                </div>
              </div>
              <el-empty v-else :description="t('common.no_data')" :image-size="60" />
            </SdCard>
          </el-col>
        </el-row>

        <SdCard class="mt-4">
          <template #header>
            <span class="font-semibold">Environment Variables</span>
          </template>
          <div v-if="container?.env && Object.keys(container.env).length">
            <el-descriptions :column="1" border size="small">
              <el-descriptions-item
                v-for="(val, key) in container.env"
                :key="key"
                :label="key"
              >
                {{ val }}
              </el-descriptions-item>
            </el-descriptions>
          </div>
          <el-empty v-else :description="t('common.no_data')" :image-size="60" />
        </SdCard>
      </el-tab-pane>

      <el-tab-pane :label="t('services.status')" name="status">
        <SdCard>
          <template #header>
            <span class="font-semibold">{{ t('services.status') }}</span>
          </template>
          <el-descriptions :column="2" border>
            <el-descriptions-item :label="t('services.status')">
              <SdStatus :status="serviceStatus" />
            </el-descriptions-item>
          </el-descriptions>
        </SdCard>
      </el-tab-pane>

      <el-tab-pane :label="t('services.logs')" name="logs">
        <SdCard>
          <template #header>
            <div class="flex items-center justify-between">
              <span class="font-semibold">{{ t('services.logs') }}</span>
              <el-button size="small" @click="fetchLogs">{{ t('common.refresh') }}</el-button>
            </div>
          </template>
          <div v-loading="logLoading" class="log-output">
            {{ logs || t('common.no_data') }}
          </div>
        </SdCard>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>
