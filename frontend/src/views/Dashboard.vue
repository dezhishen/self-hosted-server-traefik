<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { getRuntimeInfo, listContainers } from '@/api/runtime'
import type { RuntimeInfo, Container } from '@/api/runtime'
import SdCard from '@/components/SdCard.vue'
import SdStatus from '@/components/SdStatus.vue'
import { Monitor, Grid, Setting, Connection } from '@element-plus/icons-vue'

const router = useRouter()

const runtime = ref<RuntimeInfo | null>(null)
const containers = ref<Container[]>([])
const loading = ref(false)

async function fetchData() {
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

function updateCounts() {
  runningCount.value = containers.value.filter(c => c.state === 'running').length
  stoppedCount.value = containers.value.filter(c => c.state !== 'running').length
}

onMounted(() => {
  fetchData().then(() => updateCounts())
})
</script>

<template>
  <div class="page-header">
    <h2>Dashboard</h2>
  </div>

  <div v-loading="loading">
    <el-row :gutter="[20, 16]" class="mb-6">
      <el-col :xs="12" :sm="12" :md="6">
        <SdCard padding="24px">
          <div class="flex items-center gap-4">
            <el-icon :size="36" color="#409eff"><Monitor /></el-icon>
            <div>
              <p class="text-sm text-gray-500 mb-0">Engine</p>
              <p class="text-lg font-semibold m-0">{{ runtime?.engine || '-' }}</p>
            </div>
          </div>
        </SdCard>
      </el-col>
      <el-col :xs="12" :sm="12" :md="6">
        <SdCard padding="24px">
          <div class="flex items-center gap-4">
            <el-icon :size="36" color="#67c23a"><Monitor /></el-icon>
            <div>
              <p class="text-sm text-gray-500 mb-0">Version</p>
              <p class="text-lg font-semibold m-0">{{ runtime?.version || '-' }}</p>
            </div>
          </div>
        </SdCard>
      </el-col>
      <el-col :xs="12" :sm="12" :md="6">
        <SdCard padding="24px">
          <div class="flex items-center gap-4">
            <el-icon :size="36" color="#67c23a"><Grid /></el-icon>
            <div>
              <p class="text-sm text-gray-500 mb-0">Running</p>
              <p class="text-lg font-semibold m-0">{{ runningCount }}</p>
            </div>
          </div>
        </SdCard>
      </el-col>
      <el-col :xs="12" :sm="12" :md="6">
        <SdCard padding="24px">
          <div class="flex items-center gap-4">
            <el-icon :size="36" color="#f56c6c"><Grid /></el-icon>
            <div>
              <p class="text-sm text-gray-500 mb-0">Stopped</p>
              <p class="text-lg font-semibold m-0">{{ stoppedCount }}</p>
            </div>
          </div>
        </SdCard>
      </el-col>
    </el-row>

    <el-row :gutter="[20, 16]" class="mb-6">
      <el-col :xs="24" :md="12">
        <SdCard>
          <template #header>
            <span class="font-semibold">Runtime Info</span>
          </template>
          <el-descriptions :column="2" border size="small">
            <el-descriptions-item label="OS">{{ runtime?.os || '-' }}</el-descriptions-item>
            <el-descriptions-item label="Architecture">{{ runtime?.arch || '-' }}</el-descriptions-item>
            <el-descriptions-item label="CPU Cores">{{ runtime?.cpus || '-' }}</el-descriptions-item>
            <el-descriptions-item label="Memory">{{ runtime?.memory || '-' }}</el-descriptions-item>
          </el-descriptions>
        </SdCard>
      </el-col>
      <el-col :xs="24" :md="12">
        <SdCard>
          <template #header>
            <span class="font-semibold">Quick Actions</span>
          </template>
          <div class="flex flex-wrap gap-3">
            <el-button type="primary" :icon="Grid" @click="router.push('/services')">
              Manage Services
            </el-button>
            <el-button type="success" :icon="Setting" @click="router.push('/subscriptions')">
              Subscriptions
            </el-button>
            <el-button type="warning" :icon="Connection" @click="router.push('/settings')">
              Settings
            </el-button>
          </div>
        </SdCard>
      </el-col>
    </el-row>

    <SdCard>
      <template #header>
        <span class="font-semibold">Container Overview</span>
      </template>
      <div class="table-responsive">
        <el-table :data="containers" stripe border size="small" style="width: 100%; min-width: 500px;">
          <el-table-column prop="name" label="Name" />
          <el-table-column prop="image" label="Image" />
          <el-table-column prop="status" label="Status" width="120">
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
