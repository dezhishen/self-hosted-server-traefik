<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useCurrentRemote } from '@/stores/currentRemote'
import { getRuntimeInfo, listContainers } from '@/api/runtime'
import type { RuntimeInfo, Container } from '@/api/runtime'
import SdCard from '@/components/SdCard.vue'
import SdStatus from '@/components/SdStatus.vue'
import { Monitor, Grid, Connection } from '@element-plus/icons-vue'

const { t } = useI18n()
const router = useRouter()
const remoteStore = useCurrentRemote()

const runtime = ref<RuntimeInfo | null>(null)
const containers = ref<Container[]>([])
const loading = ref(false)

async function fetchData() {
  // Don't fetch until the remote store has a selected endpoint.
  // This avoids a race where the Dashboard mounts before fetchRemotes()
  // completes, causing requests without the X-Remote-Name header.
  if (!remoteStore.initialized || !remoteStore.current) return
  loading.value = true
  try {
    const [rtRes, ctRes] = await Promise.all([
      getRuntimeInfo(),
      listContainers()
    ])
    runtime.value = rtRes.data
    containers.value = ctRes.data
  } finally {
    loading.value = false
  }
}

const runningCount = ref(0)
const stoppedCount = ref(0)
const managedCount = ref(0)
const unmanagedCount = ref(0)

function updateCounts() {
  runningCount.value = containers.value.filter(c => c.state === 'running').length
  stoppedCount.value = containers.value.filter(c => c.state !== 'running').length
  managedCount.value = containers.value.filter(c => c.labels?.['selfhosted.managed'] === 'true').length
  unmanagedCount.value = containers.value.length - managedCount.value
}

// Fetch on mount if already initialized.
onMounted(() => {
  if (remoteStore.initialized && remoteStore.current) {
    fetchData().then(() => updateCounts())
  }
})

// Re-fetch when the remote becomes ready (handles the race condition).
watch(
  () => remoteStore.initialized && !!remoteStore.current,
  (ready) => {
    if (ready) fetchData().then(() => updateCounts())
  }
)
</script>

<template>
  <div class="page-header">
    <h2>{{ t('dashboard.title') }}</h2>
  </div>

  <div v-loading="loading">
    <el-row :gutter="[20, 16]" class="mb-6" style="display: flex; flex-wrap: wrap;">
      <el-col :xs="12" :sm="12" :md="6" style="display: flex;">
        <SdCard padding="24px" style="flex: 1;">
          <div class="flex items-center gap-4">
            <el-icon :size="36" color="#409eff"><Monitor /></el-icon>
            <div>
              <p class="text-sm text-gray-500 mb-0">{{ t('dashboard.engine') }}</p>
              <p class="text-lg font-semibold m-0">{{ runtime?.engine || '-' }}</p>
            </div>
          </div>
        </SdCard>
      </el-col>
      <el-col :xs="12" :sm="12" :md="6" style="display: flex;">
        <SdCard padding="24px" style="flex: 1;">
          <div class="flex items-center gap-4">
            <el-icon :size="36" color="#67c23a"><Monitor /></el-icon>
            <div>
              <p class="text-sm text-gray-500 mb-0">Version</p>
              <p class="text-lg font-semibold m-0">{{ runtime?.version || '-' }}</p>
            </div>
          </div>
        </SdCard>
      </el-col>
      <el-col :xs="12" :sm="12" :md="6" style="display: flex;">
        <SdCard padding="24px" style="flex: 1;">
          <div class="flex items-center gap-4">
            <el-icon :size="36" color="#67c23a"><Grid /></el-icon>
            <div>
              <p class="text-sm text-gray-500 mb-0">{{ t('dashboard.running') }}</p>
              <p class="text-lg font-semibold m-0">{{ runningCount }}</p>
            </div>
          </div>
        </SdCard>
      </el-col>
      <el-col :xs="12" :sm="12" :md="6" style="display: flex;">
        <SdCard padding="24px" style="flex: 1;">
          <div class="flex items-center gap-4">
            <el-icon :size="36" color="#f56c6c"><Grid /></el-icon>
            <div>
              <p class="text-sm text-gray-500 mb-0">{{ t('dashboard.stopped') }}</p>
              <p class="text-lg font-semibold m-0">{{ stoppedCount }}</p>
            </div>
          </div>
        </SdCard>
      </el-col>
    </el-row>

    <el-row :gutter="[20, 16]" class="mb-6" style="display: flex; flex-wrap: wrap;">
      <el-col :xs="24" :md="12" style="display: flex;">
        <SdCard style="flex: 1;">
          <template #header>
            <span class="font-semibold">{{ t('dashboard.overview') }}</span>
          </template>
          <div class="flex gap-6">
            <div class="text-center flex-1">
              <p class="text-2xl font-bold m-0">{{ containers.length }}</p>
              <p class="text-sm text-gray-500 mb-0">{{ t('dashboard.total') }}</p>
            </div>
            <div class="text-center flex-1">
              <p class="text-2xl font-bold m-0 text-green-500">{{ managedCount }}</p>
              <p class="text-sm text-gray-500 mb-0">{{ t('dashboard.managed') }}</p>
            </div>
            <div class="text-center flex-1">
              <p class="text-2xl font-bold m-0 text-orange-500">{{ unmanagedCount }}</p>
              <p class="text-sm text-gray-500 mb-0">{{ t('dashboard.unmanaged') }}</p>
            </div>
          </div>
          <div v-if="unmanagedCount > 0" class="mt-3 text-center">
            <el-button size="small" :icon="Connection" @click="router.push('/migrate')">
              {{ t('dashboard.adopt_unmanaged') }}
            </el-button>
          </div>
        </SdCard>
      </el-col>
      <el-col :xs="24" :md="12" style="display: flex;">
        <SdCard style="flex: 1;">
          <template #header>
            <span class="font-semibold">{{ t('dashboard.runtime') }}</span>
          </template>
          <el-descriptions :column="2" border size="small">
            <el-descriptions-item :label="t('dashboard.engine')">{{ runtime?.engine || '-' }}</el-descriptions-item>
            <el-descriptions-item label="Version">{{ runtime?.version || '-' }}</el-descriptions-item>
          </el-descriptions>
        </SdCard>
      </el-col>
    </el-row>

    <SdCard>
      <template #header>
        <span class="font-semibold">{{ t('dashboard.containers') }}</span>
      </template>
      <div class="table-responsive">
        <el-table :data="containers" stripe border size="small" style="width: 100%; min-width: 500px;">
          <el-table-column prop="name" label="Name" />
          <el-table-column prop="image" label="Image" />
          <el-table-column prop="status" :label="t('services.status')" width="120">
            <template #default="{ row }">
              <SdStatus :status="row.state" />
            </template>
          </el-table-column>
          <el-table-column prop="uptime" label="Uptime" width="160" />
        </el-table>
      </div>
    </SdCard>
  </div>
</template>
