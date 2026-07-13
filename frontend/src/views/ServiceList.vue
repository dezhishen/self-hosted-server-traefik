<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { listServices, installService, restartService, uninstallService, previewService } from '@/api/services'
import type { Service, ContainerRunParams } from '@/api/services'
import SdStatus from '@/components/SdStatus.vue'
import { Plus, Search, Refresh, VideoPlay, Download, InfoFilled, Loading } from '@element-plus/icons-vue'
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
const paramValues = ref<Record<string, unknown>>({})

const selectedService = computed(() => {
  if (!installTarget.value) return null
  return availableServices.value.find(s => s.name === installTarget.value) || null
})

// Preview
const previewResult = ref<ContainerRunParams | null>(null)
const previewLoading = ref(false)
const previewTimer = ref<ReturnType<typeof setTimeout> | null>(null)

function openInstallDialog() {
  installTarget.value = ''
  paramValues.value = {}
  previewResult.value = null
  installDialogVisible.value = true
  // Load available services (templates from subscriptions)
  listServices().then(res => {
    availableServices.value = res.data || []
  })
}

function initParamDefaults(svc: Service | null) {
  if (!svc?.params) return
  const values: Record<string, unknown> = {}
  for (const p of svc.params) {
    values[p.name] = p.default ?? (p.type === 'bool' ? false : '')
  }
  paramValues.value = values
}

watch(installTarget, (name) => {
  previewResult.value = null
  if (previewTimer.value) clearTimeout(previewTimer.value)
  if (!name) {
    paramValues.value = {}
    return
  }
  const svc = availableServices.value.find(s => s.name === name)
  initParamDefaults(svc || null)
})

watch(paramValues, () => {
  if (!installTarget.value) return
  if (previewTimer.value) clearTimeout(previewTimer.value)
  previewTimer.value = setTimeout(fetchPreview, 600)
}, { deep: true })

async function fetchPreview() {
  if (!installTarget.value) return
  previewLoading.value = true
  try {
    const params = buildParamList()
    const res = await previewService(installTarget.value, params)
    previewResult.value = res.data
  } catch {
    previewResult.value = null
  } finally {
    previewLoading.value = false
  }
}

function buildParamList(): { name: string; value: unknown }[] {
  const svc = selectedService.value
  if (!svc?.params) return []
  return svc.params
    .filter(p => {
      const v = paramValues.value[p.name]
      return v !== '' && v !== null && v !== undefined
    })
    .map(p => ({ name: p.name, value: paramValues.value[p.name] }))
}

function formatPreview(params: ContainerRunParams): string {
  const lines: string[] = ['docker run -d']
  if (params.name) lines.push(`  --name ${params.name}`)
  if (params.restart_policy) lines.push(`  --restart ${params.restart_policy}`)
  if (params.network_mode) lines.push(`  --network ${params.network_mode}`)
  if (params.privileged) lines.push('  --privileged')
  if (params.user) lines.push(`  --user ${params.user}`)
  if (params.labels) {
    for (const [k, v] of Object.entries(params.labels)) {
      lines.push(`  --label ${k}=${v}`)
    }
  }
  if (params.env) {
    for (const [k, v] of Object.entries(params.env)) {
      lines.push(`  -e ${k}=${v}`)
    }
  }
  if (params.ports) {
    for (const p of params.ports) {
      lines.push(`  -p ${p.host_port}:${p.container_port}${p.protocol && p.protocol !== 'tcp' ? '/' + p.protocol : ''}`)
    }
  }
  if (params.volumes) {
    for (const v of params.volumes) {
      lines.push(`  -v ${v.source}:${v.target}${v.read_only ? ':ro' : ''}`)
    }
  }
  if (params.image) lines.push(`  ${params.image}`)
  if (params.command?.length) lines.push(`  ${params.command.join(' ')}`)
  return lines.join(' \\\n')
}

async function executeInstall() {
  if (!installTarget.value) return
  installing.value = true
  try {
    const params = buildParamList()
    await installService({ name: installTarget.value, params })
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
    const res = await listServices(keyword.value || undefined, true)
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
    width="min(680px, 94vw)"
    :close-on-click-modal="false"
  >
    <el-form @submit.prevent="executeInstall" label-position="top">
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

      <!-- Template parameters -->
      <template v-if="selectedService?.params?.length">
        <el-divider content-position="left">Configuration</el-divider>
        <el-row :gutter="16">
          <el-col
            v-for="p in selectedService.params"
            :key="p.name"
            :xs="24"
            :sm="p.type === 'bool' ? 12 : 12"
            :md="p.type === 'bool' ? 8 : p.type === 'select' ? 12 : 8"
          >
            <el-form-item
              :label="p.label || p.name"
              :required="p.required"
              :class="{ 'mb-4': true }"
            >
              <!-- String / Number -->
              <el-input
                v-if="p.type === 'string' || p.type === 'number'"
                v-model="paramValues[p.name]"
                :type="p.type === 'number' ? 'number' : 'text'"
                :placeholder="p.description || p.name"
                :disabled="installing"
              />

              <!-- Password -->
              <el-input
                v-else-if="p.type === 'password'"
                v-model="paramValues[p.name]"
                type="password"
                show-password
                :placeholder="p.description || p.name"
                :disabled="installing"
              />

              <!-- Boolean -->
              <el-switch
                v-else-if="p.type === 'bool'"
                v-model="paramValues[p.name]"
                :disabled="installing"
              />

              <!-- Select -->
              <el-select
                v-else-if="p.type === 'select' && p.options"
                v-model="paramValues[p.name]"
                filterable
                style="width: 100%"
                :placeholder="t('common.select') || 'Select'"
                :disabled="installing"
              >
                <el-option
                  v-for="opt in p.options"
                  :key="typeof opt === 'string' ? opt : opt.value"
                  :label="typeof opt === 'string' ? opt : opt.label"
                  :value="typeof opt === 'string' ? opt : opt.value"
                />
              </el-select>

              <!-- Array -->
              <el-input
                v-else-if="p.type === 'array'"
                v-model="paramValues[p.name]"
                :placeholder="p.description || (p.label || p.name) + ' (comma-separated)'"
                :disabled="installing"
              >
                <template #append>
                  <el-tooltip content="Separate items with commas" placement="top">
                    <el-icon><InfoFilled /></el-icon>
                  </el-tooltip>
                </template>
              </el-input>

              <!-- Fallback -->
              <el-input
                v-else
                v-model="paramValues[p.name]"
                :placeholder="p.description || p.name"
                :disabled="installing"
              />

              <!-- Description hint -->
              <span v-if="p.description" class="text-xs text-gray-400 mt-1 block">{{ p.description }}</span>
            </el-form-item>
          </el-col>
        </el-row>
      </template>

      <!-- Preview -->
      <template v-if="installTarget">
        <el-divider content-position="left">{{ t('services.preview') || 'Preview' }}</el-divider>
        <div v-if="previewLoading" class="text-center py-4">
          <el-icon class="is-loading"><Loading /></el-icon>
        </div>
        <div v-else-if="previewResult" class="preview-box">
          <el-input
            type="textarea"
            :rows="6"
            :model-value="formatPreview(previewResult)"
            readonly
            class="font-mono text-sm"
          />
        </div>
        <div v-else class="text-center py-4 text-gray-400 text-sm">
          {{ t('services.preview_hint') || 'Fill in parameters to see preview' }}
        </div>
      </template>
    </el-form>
    <template #footer>
      <el-button @click="installDialogVisible = false">{{ t('common.close') }}</el-button>
      <el-button type="primary" :icon="Download" :loading="installing" :disabled="!installTarget" @click="executeInstall">
        {{ installing ? t('services.installing') : t('services.install') }}
      </el-button>
    </template>
  </el-dialog>
</template>

<style scoped>
.preview-box :deep(.el-textarea__inner) {
  background-color: var(--el-fill-color-light);
  color: var(--el-text-color-primary);
  font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
  font-size: 12px;
  line-height: 1.6;
}
</style>
