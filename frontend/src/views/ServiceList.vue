<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { listServices, installService, restartService, uninstallService } from '@/api/services'
import type { Service } from '@/api/services'
import SdStatus from '@/components/SdStatus.vue'
import { Plus, Search, Refresh, VideoPlay, Download } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const { t } = useI18n()
const router = useRouter()
const services = ref<Service[]>([])
const loading = ref(false)
const keyword = ref('')

// Install dialog
const installDialogVisible = ref(false)
const installTarget = ref('')
const installing = ref(false)
const availableServices = ref<Service[]>([])

function openInstallDialog() {
  installTarget.value = ''
  installDialogVisible.value = true
  // Load available services (templates from subscriptions)
  listServices().then(res => {
    availableServices.value = res.data || []
  })
}

async function executeInstall() {
  if (!installTarget.value) return
  installing.value = true
  try {
    await installService({ name: installTarget.value, params: [] })
    ElMessage.success(t('common.success'))
    installDialogVisible.value = false
    fetchServices()
  } catch {
    // error handled by global handler
  } finally {
    installing.value = false
  }
}

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
    // 错误由全局 errorHandler 注册链处理
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
    // 用户取消确认框 或 错误由全局 errorHandler 处理
  }
}

onMounted(fetchServices)
</script>

<template>
  <div class="page-header flex items-center justify-between flex-wrap gap-2">
    <h2>{{ t('services.title') }}</h2>
    <el-button type="primary" :icon="Plus" @click="openInstallDialog">{{ t('services.install') }}</el-button>
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
    <el-table :data="services" stripe border size="small" v-loading="loading" style="width: 100%; min-width: 650px;">
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

  <!-- Install dialog -->
  <el-dialog
    v-model="installDialogVisible"
    :title="t('services.install')"
    width="min(600px, 92vw)"
    :close-on-click-modal="false"
  >
    <el-form @submit.prevent="executeInstall">
      <el-form-item :label="t('services.select') || 'Select service'" required>
        <el-select v-model="installTarget" filterable style="width: 100%;" :placeholder="t('services.select') || 'Select service'">
          <el-option
            v-for="svc in availableServices"
            :key="svc.name"
            :label="`${svc.name}${svc.description ? ' — ' + svc.description : ''}`"
            :value="svc.name"
          >
            <div class="flex items-center justify-between">
              <span>{{ svc.name }}</span>
              <span class="text-xs text-gray-400 ml-2">{{ svc.category }}</span>
            </div>
          </el-option>
        </el-select>
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="installDialogVisible = false">{{ t('common.close') }}</el-button>
      <el-button type="primary" :icon="Download" :loading="installing" :disabled="!installTarget" @click="executeInstall">
        {{ installing ? t('services.installing') : t('services.install') }}
      </el-button>
    </template>
  </el-dialog>
</template>
