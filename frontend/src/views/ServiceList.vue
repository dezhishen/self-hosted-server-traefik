<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { listServices, restartService, uninstallService } from '@/api/services'
import type { Service } from '@/api/services'
import SdStatus from '@/components/SdStatus.vue'
import { Plus, Search, Refresh, VideoPlay } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const { t } = useI18n()
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
    ElMessage.success(t('common.success'))
  } catch {
  }
}

async function handleUninstall(name: string) {
  try {
    await ElMessageBox.confirm(
      t('services.uninstall') + ` "${name}"?`,
      t('common.confirm'),
      { confirmButtonText: t('services.uninstall'), cancelButtonText: t('common.close'), type: 'warning' }
    )
    await uninstallService(name)
    ElMessage.success(t('common.success'))
    fetchServices()
  } catch {
  }
}

onMounted(fetchServices)
</script>

<template>
  <div class="page-header flex items-center justify-between flex-wrap gap-2">
    <h2>{{ t('services.title') }}</h2>
    <el-button type="primary" :icon="Plus" size="small">{{ t('services.install') }}</el-button>
  </div>

  <div class="mb-4 flex flex-wrap gap-3">
    <el-input
      v-model="keyword"
      :placeholder="t('services.search')"
      clearable
      class="max-w-sm flex-1 min-w-[200px]"
      @keyup.enter="handleSearch"
    >
      <template #prefix>
        <el-icon><Search /></el-icon>
      </template>
    </el-input>
    <el-button :icon="Refresh" @click="fetchServices">{{ t('common.refresh') || 'Refresh' }}</el-button>
  </div>

  <div class="table-responsive">
    <el-table :data="services" stripe border v-loading="loading" style="width: 100%; min-width: 650px;">
    <el-table-column prop="name" label="Name" min-width="160">
      <template #default="{ row }">
        <el-link type="primary" @click="viewDetail(row.name)">{{ row.name }}</el-link>
      </template>
    </el-table-column>
    <el-table-column prop="description" :label="t('common.desc') || 'Description'" min-width="200" show-overflow-tooltip />
    <el-table-column prop="category" :label="t('common.category') || 'Category'" width="120" />
    <el-table-column :label="t('services.status')" width="110">
      <template #default="{ row }">
        <SdStatus :status="row.tags?.length ? 'running' : 'stopped'" />
      </template>
    </el-table-column>
    <el-table-column :label="t('common.actions') || 'Actions'" width="260">
      <template #default="{ row }">
        <div class="flex gap-2">
          <el-button size="small" type="primary" plain @click="viewDetail(row.name)">{{ t('common.detail') || 'Detail' }}</el-button>
          <el-button size="small" type="success" plain :icon="VideoPlay" @click="handleRestart(row.name)">{{ t('services.restart') }}</el-button>
          <el-button size="small" type="danger" plain @click="handleUninstall(row.name)">{{ t('services.uninstall') }}</el-button>
        </div>
      </template>
    </el-table-column>
  </el-table>
  </div>
</template>
