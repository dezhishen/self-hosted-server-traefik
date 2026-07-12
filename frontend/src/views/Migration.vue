<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  analyzeMigrations,
  executeMigration,
  generateApp,
  adoptContainer,
} from '@/api/migrate'
import type {
  MigrationCandidate,
  MigrationRequest,
  GenerateAppRequest,
  AdoptRequest,
} from '@/api/migrate'
import { listContainers } from '@/api/runtime'
import type { Container } from '@/api/runtime'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Promotion, View, Document, Connection } from '@element-plus/icons-vue'

const { t } = useI18n()

// ===== Migration tab =====

const candidates = ref<MigrationCandidate[]>([])
const loading = ref(false)
const selected = ref<MigrationCandidate | null>(null)
const step = ref<'list' | 'detail'>('list')
const executing = ref(false)

async function fetchCandidates() {
  loading.value = true
  try {
    const res = await analyzeMigrations()
    candidates.value = res.data
  } finally {
    loading.value = false
  }
}

function showDetail(candidate: MigrationCandidate) {
  selected.value = candidate
  step.value = 'detail'
}

function back() {
  step.value = 'list'
  selected.value = null
}

async function handleMigrate() {
  if (!selected.value) return
  try {
    await ElMessageBox.confirm(
      t('migration.confirm_migrate'),
      t('common.confirm'),
      { confirmButtonText: t('migration.migrate'), cancelButtonText: t('common.close'), type: 'warning' }
    )
  } catch {
    return
  }
  executing.value = true
  try {
    const req: MigrationRequest = {
      container_id: selected.value.container.id,
      service_name: selected.value.matched_service || '',
      params: selected.value.extracted_params || [],
      remove_old: true
    }
    const res = await executeMigration(req)
    ElMessage.success(t('migration.success') + ': ' + res.data.container_id)
    step.value = 'list'
    selected.value = null
    fetchCandidates()
  } finally {
    executing.value = false
  }
}

// Generate template dialog state
const generateDialogVisible = ref(false)
const generateSvcName = ref('')
const generating = ref(false)

async function handleGenerate() {
  if (!selected.value || !selected.value.matched_service) return
  generateSvcName.value = selected.value.matched_service
  generateDialogVisible.value = true
}

async function confirmGenerate() {
  if (!selected.value || !generateSvcName.value) return
  generating.value = true
  try {
    const req: GenerateAppRequest = {
      container_id: selected.value.container.id,
      service_name: generateSvcName.value,
    }
    await generateApp(req)
    ElMessage.success(t('migration.generate_success') + ': ' + generateSvcName.value)
    generateDialogVisible.value = false
    fetchCandidates()
  } catch (e: any) {
    ElMessage.error(e?.response?.data?.error || t('migration.generate_error'))
  } finally {
    generating.value = false
  }
}

function updateParam(index: number, value: unknown) {
  if (selected.value && selected.value.extracted_params) {
    selected.value.extracted_params[index].value = value
  }
}

// ===== Adopt tab =====

const unmanagedContainers = ref<Container[]>([])
const adoptLoading = ref(false)
const adoptDialogVisible = ref(false)
const adoptContainerId = ref('')
const adoptContainerName = ref('')
const adoptServiceName = ref('')
const adopting = ref(false)

async function fetchUnmanaged() {
  adoptLoading.value = true
  try {
    const res = await listContainers()
    const managedKey = 'selfhosted.managed'
    unmanagedContainers.value = res.data.filter(
      (c: Container) => c.labels?.[managedKey] !== 'true'
    )
  } finally {
    adoptLoading.value = false
  }
}

function openAdoptDialog(container: Container) {
  adoptContainerId.value = container.id
  adoptContainerName.value = container.name
  adoptServiceName.value = container.name
  adoptDialogVisible.value = true
}

async function confirmAdopt() {
  if (!adoptContainerId.value || !adoptServiceName.value) return
  adopting.value = true
  try {
    const req: AdoptRequest = {
      container_id: adoptContainerId.value,
      service_name: adoptServiceName.value,
    }
    await adoptContainer(req)
    ElMessage.success(t('adopt.success') + ': ' + adoptServiceName.value)
    adoptDialogVisible.value = false
    await fetchUnmanaged()
  } catch (e: any) {
    ElMessage.error(e?.response?.data?.error || t('adopt.error'))
  } finally {
    adopting.value = false
  }
}

// ===== Tab toggle =====

const activeTab = ref<'migrate' | 'adopt'>('migrate')

onMounted(() => {
  if (activeTab.value === 'migrate') {
    fetchCandidates()
  }
})

function switchTab(tab: 'migrate' | 'adopt') {
  activeTab.value = tab
  if (tab === 'migrate') {
    fetchCandidates()
  } else {
    fetchUnmanaged()
  }
}
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <h2>{{ t('nav.migration') }}</h2>
    <el-button :icon="Promotion" @click="fetchCandidates" :disabled="loading">
      {{ t('common.refresh') }}
    </el-button>
  </div>

  <el-tabs v-model="activeTab" class="mt-4" @tab-change="switchTab">
    <el-tab-pane :label="t('migration.title')" name="migrate">
      <template v-if="step === 'list'">
        <div class="table-responsive">
          <el-table :data="candidates" stripe border size="small" v-loading="loading" style="width: 100%; min-width: 700px;">
            <el-table-column prop="container.name" :label="t('migration.container_name')" min-width="180" />
            <el-table-column prop="container.image" :label="t('migration.image')" min-width="200" show-overflow-tooltip />
            <el-table-column prop="container.state" :label="t('services.status')" width="110">
              <template #default="{ row }">
                <el-tag :type="row.container.state === 'running' ? 'success' : 'info'" size="small">
                  {{ row.container.state }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="matched_service" :label="t('migration.matched_service')" min-width="160">
              <template #default="{ row }">
                <el-tag v-if="row.matched_service" type="primary" size="small">{{ row.matched_service }}</el-tag>
                <span v-else class="text-gray-400">—</span>
              </template>
            </el-table-column>
            <el-table-column :label="t('common.actions')" width="100">
              <template #default="{ row }">
                <el-button size="small" :icon="View" @click="showDetail(row)">
                  {{ t('common.detail') }}
                </el-button>
              </template>
            </el-table-column>
          </el-table>
          <div v-if="!loading && candidates.length === 0" class="text-center text-gray-400 py-8">
            {{ t('migration.no_unmanaged') }}
          </div>
        </div>
      </template>

      <template v-else-if="step === 'detail' && selected">
        <el-button size="small" @click="back">{{ t('common.back') }}</el-button>

        <el-card class="mt-4">
          <template #header>
            <span>{{ t('migration.container_config') }}</span>
          </template>
          <el-descriptions :column="1" border>
            <el-descriptions-item :label="t('migration.container_name')">
              {{ selected.container.name }}
            </el-descriptions-item>
            <el-descriptions-item label="ID">
              <code class="text-xs">{{ selected.container.id }}</code>
            </el-descriptions-item>
            <el-descriptions-item :label="t('migration.image')">
              {{ selected.container.image }}
            </el-descriptions-item>
            <el-descriptions-item :label="t('services.status')">
              {{ selected.container.state }}
            </el-descriptions-item>
          </el-descriptions>
        </el-card>

        <el-card class="mt-4">
          <template #header>
            <span>{{ t('migration.service_selection') }}</span>
          </template>
          <el-form label-position="top">
            <el-form-item :label="t('migration.select_service')">
              <el-select v-model="selected.matched_service" filterable style="width: 100%;">
                <el-option
                  v-for="svc in selected.services"
                  :key="svc"
                  :label="svc"
                  :value="svc"
                />
              </el-select>
            </el-form-item>
          </el-form>
        </el-card>

        <el-card v-if="selected.extracted_params && selected.extracted_params.length > 0" class="mt-4">
          <template #header>
            <span>{{ t('migration.params') }}</span>
          </template>
          <el-form label-position="top">
            <el-form-item
              v-for="(param, idx) in selected.extracted_params"
              :key="param.name"
              :label="param.name"
            >
              <el-input
                :model-value="String(param.value ?? '')"
                @input="(val: string) => updateParam(idx, val)"
              />
            </el-form-item>
          </el-form>
        </el-card>

        <div class="mt-6 flex gap-3">
          <el-button
            type="primary"
            :icon="Promotion"
            :loading="executing"
            :disabled="!selected.matched_service"
            @click="handleMigrate"
          >
            {{ t('migration.migrate') }}
          </el-button>
          <el-button
            :icon="Document"
            :disabled="!selected.matched_service"
            @click="handleGenerate"
          >
            {{ t('migration.generate_app') }}
          </el-button>
        </div>
      </template>
    </el-tab-pane>

    <el-tab-pane :label="t('adopt.title')" name="adopt">
      <div class="table-responsive">
        <el-table :data="unmanagedContainers" stripe border size="small" v-loading="adoptLoading" style="width: 100%; min-width: 600px;">
          <el-table-column prop="name" :label="t('migration.container_name')" min-width="180" />
          <el-table-column prop="image" :label="t('migration.image')" min-width="200" show-overflow-tooltip />
          <el-table-column prop="status" :label="t('services.status')" width="120">
            <template #default="{ row }">
              <el-tag :type="row.state === 'running' ? 'success' : 'info'" size="small">
                {{ row.state }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column :label="t('common.actions')" width="100">
            <template #default="{ row }">
              <el-button size="small" type="primary" :icon="Connection" @click="openAdoptDialog(row)">
                {{ t('adopt.adopt') }}
              </el-button>
            </template>
          </el-table-column>
        </el-table>
        <div v-if="!adoptLoading && unmanagedContainers.length === 0" class="text-center text-gray-400 py-8">
          {{ t('adopt.no_unmanaged') }}
        </div>
      </div>
    </el-tab-pane>
  </el-tabs>

  <!-- Generate Template Dialog -->
  <el-dialog
    v-model="generateDialogVisible"
    :title="t('migration.generate_app')"
    width="500px"
  >
    <el-form label-position="top">
      <el-form-item :label="t('migration.generate_name')">
        <el-input v-model="generateSvcName" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="generateDialogVisible = false">{{ t('common.close') }}</el-button>
      <el-button type="primary" :loading="generating" @click="confirmGenerate">
        {{ t('migration.generate_save') }}
      </el-button>
    </template>
  </el-dialog>

  <!-- Adopt Dialog -->
  <el-dialog
    v-model="adoptDialogVisible"
    :title="t('adopt.dialog_title')"
    width="500px"
  >
    <el-form label-position="top">
      <el-form-item :label="t('adopt.container_id')">
        <el-input :model-value="adoptContainerId" disabled />
      </el-form-item>
      <el-form-item :label="t('adopt.service_name')">
        <el-input v-model="adoptServiceName" :placeholder="adoptContainerName" />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="adoptDialogVisible = false">{{ t('common.close') }}</el-button>
      <el-button type="primary" :loading="adopting" @click="confirmAdopt">
        {{ t('adopt.adopt') }}
      </el-button>
    </template>
  </el-dialog>
</template>
