<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listServices, restartService, uninstallService } from '@/api/services'
import type { Service } from '@/api/services'
import SdStatus from '@/components/SdStatus.vue'
import { Plus, Search, Refresh, VideoPlay } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const router = useRouter()
const services = ref<Service[]>([])
const loading = ref(false)
const keyword = ref('')

async function fetchServices() {
  loading.value = true
  try {
    const res = await listServices(keyword.value || undefined)
    services.value = res.data
  } finally {
    loading.value = false
  }
}

function handleSearch() {
  fetchServices()
}

function viewDetail(name: string) {
  router.push(`/services/${name}`)
}

async function handleRestart(name: string) {
  try {
    await restartService(name)
    ElMessage.success('Service restarted')
  } catch {
  }
}

async function handleUninstall(name: string) {
  try {
    await ElMessageBox.confirm(
      `Are you sure you want to uninstall "${name}"?`,
      'Confirm Uninstall',
      { confirmButtonText: 'Uninstall', cancelButtonText: 'Cancel', type: 'warning' }
    )
    await uninstallService(name)
    ElMessage.success(`Service "${name}" uninstalled`)
    fetchServices()
  } catch {
  }
}

onMounted(fetchServices)
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <h2>Services</h2>
    <el-button type="primary" :icon="Plus">Install Service</el-button>
  </div>

  <div class="mb-4 flex gap-3">
    <el-input
      v-model="keyword"
      placeholder="Search services..."
      clearable
      class="max-w-sm"
      @keyup.enter="handleSearch"
    >
      <template #prefix>
        <el-icon><Search /></el-icon>
      </template>
    </el-input>
    <el-button :icon="Refresh" @click="fetchServices">Refresh</el-button>
  </div>

  <el-table :data="services" stripe border v-loading="loading" style="width: 100%">
    <el-table-column prop="name" label="Name" min-width="160">
      <template #default="{ row }">
        <el-link type="primary" @click="viewDetail(row.name)">{{ row.name }}</el-link>
      </template>
    </el-table-column>
    <el-table-column prop="description" label="Description" min-width="200" show-overflow-tooltip />
    <el-table-column prop="category" label="Category" width="120" />
    <el-table-column label="Status" width="110">
      <template #default="{ row }">
        <SdStatus :status="row.tags?.length ? 'running' : 'stopped'" />
      </template>
    </el-table-column>
    <el-table-column label="Actions" width="260" fixed="right">
      <template #default="{ row }">
        <div class="flex gap-2">
          <el-button size="small" type="primary" plain @click="viewDetail(row.name)">Detail</el-button>
          <el-button size="small" type="success" plain :icon="VideoPlay" @click="handleRestart(row.name)">Restart</el-button>
          <el-button size="small" type="danger" plain @click="handleUninstall(row.name)">Uninstall</el-button>
        </div>
      </template>
    </el-table-column>
  </el-table>
</template>
