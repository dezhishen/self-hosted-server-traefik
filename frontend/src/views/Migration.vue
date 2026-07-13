<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  analyzeMigrations,
  generateApp,
  adoptContainer,
} from '@/api/migrate'
import type {
  MigrationCandidate,
  GenerateAppRequest,
  AdoptRequest,
} from '@/api/migrate'
import { listContainers } from '@/api/runtime'
import type { Container } from '@/api/runtime'
import { ElMessage, ElMessageBox } from 'element-plus'
import { previewService } from '@/api/services'
import type { ContainerRunParams } from '@/api/services'
import { Promotion, View, Document, Connection, Search } from '@element-plus/icons-vue'

const { t } = useI18n()

// ===== State =====

const candidates = ref<MigrationCandidate[]>([])
const loading = ref(false)
const selected = ref<MigrationCandidate | null>(null)
const step = ref<'list' | 'detail'>('list')
const executing = ref(false)

async function fetchData() {
  loading.value = true
  try {
    const [migRes] = await Promise.all([
      analyzeMigrations(),
    ])
    candidates.value = migRes.data
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

// ===== Adopt (with rebuild) via preview → confirm =====

async function handleAdoptWithRebuild(skipConfirm?: boolean) {
  if (!selected.value) return
  if (!skipConfirm) {
    try {
      await ElMessageBox.confirm(
        t('migration.confirm_migrate'),
        t('common.confirm'),
        { confirmButtonText: t('migration.migrate'), cancelButtonText: t('common.close'), type: 'warning' }
      )
    } catch {
      return
    }
  }
  executing.value = true
  try {
    const req: AdoptRequest = {
      container_id: selected.value.container.id,
      service_name: selected.value.matched_service || '',
      params: selected.value.extracted_params || [],
      rebuild: true,
    }
    const res = await adoptContainer(req)
    ElMessage.success(t('adopt.success') + ': ' + res.data.service_name)
    previewDialogVisible.value = false
    step.value = 'list'
    selected.value = null
    fetchData()
  } finally {
    executing.value = false
  }
}

// ===== Adopt in-place (no rebuild) from detail view =====

async function handleAdoptInPlace() {
  if (!selected.value) return
  executing.value = true
  try {
    const req: AdoptRequest = {
      container_id: selected.value.container.id,
      service_name: selected.value.matched_service || selected.value.container.name,
      params: selected.value.extracted_params || [],
      rebuild: false,
    }
    const res = await adoptContainer(req)
    ElMessage.success(t('adopt.success') + ': ' + res.data.service_name)
    step.value = 'list'
    selected.value = null
    fetchData()
  } catch (e: any) {
    ElMessage.error(e?.response?.data?.error || t('adopt.error'))
  } finally {
    executing.value = false
  }
}

// ===== Quick adopt from table row =====

const adoptDialogVisible = ref(false)
const adoptContainerId = ref('')
const adoptContainerName = ref('')
const adoptServiceName = ref('')
const adopting = ref(false)

function openQuickAdopt(candidate: MigrationCandidate) {
  adoptContainerId.value = candidate.container.id
  adoptContainerName.value = candidate.container.name
  adoptServiceName.value = candidate.matched_service || candidate.container.name
  adoptDialogVisible.value = true
}

async function confirmQuickAdopt() {
  if (!adoptContainerId.value || !adoptServiceName.value) return
  adopting.value = true
  try {
    const req: AdoptRequest = {
      container_id: adoptContainerId.value,
      service_name: adoptServiceName.value,
      rebuild: false,
    }
    await adoptContainer(req)
    ElMessage.success(t('adopt.success') + ': ' + adoptServiceName.value)
    adoptDialogVisible.value = false
    await fetchData()
  } catch (e: any) {
    ElMessage.error(e?.response?.data?.error || t('adopt.error'))
  } finally {
    adopting.value = false
  }
}

// ===== Preview dialog =====

const previewDialogVisible = ref(false)
const previewRunParams = ref<ContainerRunParams | null>(null)
const previewing = ref(false)

async function handlePreview() {
  if (!selected.value || !selected.value.matched_service) return
  previewing.value = true
  try {
    const res = await previewService(
      selected.value.matched_service,
      selected.value.extracted_params || []
    )
    previewRunParams.value = res.data
    previewDialogVisible.value = true
  } catch (e: any) {
    ElMessage.error(e?.response?.data?.error || t('migration.preview_error'))
  } finally {
    previewing.value = false
  }
}

function previewEnvList(): { key: string; value: string }[] {
  if (!previewRunParams.value?.env) return []
  return Object.entries(previewRunParams.value.env).map(([k, v]) => ({ key: k, value: v }))
}

function previewPortList(): string[] {
  if (!previewRunParams.value?.ports) return []
  return previewRunParams.value.ports.map(
    p => `${p.host_port}:${p.container_port}${p.protocol ? '/' + p.protocol : ''}`
  )
}

function previewVolumeList(): string[] {
  if (!previewRunParams.value?.volumes) return []
  return previewRunParams.value.volumes.map(
    v => `${v.source}:${v.target}${v.read_only ? ':ro' : ''}`
  )
}

// ===== Generate template dialog =====

const generateDialogVisible = ref(false)
const generateSvcName = ref('')
const generating = ref(false)

function handleGenerate() {
  if (!selected.value) return
  generateSvcName.value = selected.value.matched_service || selected.value.container.name
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
    fetchData()
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

// ===== Lifecycle =====

onMounted(() => {
  fetchData()
})
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <h2>{{ t('adopt.title') }}</h2>
    <el-button :icon="Promotion" @click="fetchData" :disabled="loading">
      {{ t('common.refresh') }}
    </el-button>
  </div>

  <!-- ===== List view ===== -->
  <template v-if="step === 'list'">
    <div class="table-responsive">
      <el-table
        :data="candidates"
        stripe
        border
        size="small"
        v-loading="loading"
        style="width: 100%; min-width: 700px;"
      >
        <el-table-column prop="container.name" :label="t('migration.container_name')" min-width="160" />
        <el-table-column prop="container.image" :label="t('migration.image')" min-width="200" show-overflow-tooltip />
        <el-table-column prop="container.state" :label="t('services.status')" width="100">
          <template #default="{ row }">
            <el-tag :type="row.container.state === 'running' ? 'success' : 'info'" size="small">
              {{ row.container.state }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="matched_service" :label="t('migration.matched_service')" min-width="150">
          <template #default="{ row }">
            <el-tag v-if="row.matched_service" type="primary" size="small">{{ row.matched_service }}</el-tag>
            <span v-else class="text-gray-400">—</span>
          </template>
        </el-table-column>
        <el-table-column :label="t('common.actions')" width="180" fixed="right">
          <template #default="{ row }">
            <div class="flex gap-2">
              <el-button size="small" type="primary" :icon="View" @click="showDetail(row)">
                {{ t('adopt.manage') }}
              </el-button>
              <el-button size="small" :icon="Connection" @click="openQuickAdopt(row)">
                {{ t('adopt.adopt') }}
              </el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && candidates.length === 0" class="text-center text-gray-400 py-8">
        {{ t('adopt.no_unmanaged') }}
      </div>
    </div>
  </template>

  <!-- ===== Detail view ===== -->
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

    <div class="mt-6 flex gap-3 flex-wrap">
      <!-- Preview + rebuild flow (only when service matched) -->
      <template v-if="selected.matched_service">
        <el-button
          type="primary"
          :icon="Search"
          :loading="previewing"
          @click="handlePreview"
        >
          {{ t('migration.preview') }}
        </el-button>
        <el-button
          :icon="Document"
          @click="handleGenerate"
        >
          {{ t('migration.generate_app') }}
        </el-button>
        <el-button
          :icon="Connection"
          :loading="executing"
          plain
          @click="handleAdoptInPlace"
        >
          {{ t('adopt.adopt_in_place') }}
        </el-button>
      </template>
      <!-- No match: generate + in-place -->
      <template v-else>
        <el-button
          :icon="Document"
          @click="handleGenerate"
        >
          {{ t('migration.generate_app') }}
        </el-button>
        <el-button
          type="primary"
          :icon="Connection"
          :loading="executing"
          @click="handleAdoptInPlace"
        >
          {{ t('adopt.adopt_in_place') }}
        </el-button>
      </template>
    </div>
  </template>

  <!-- ===== Preview Dialog ===== -->
  <el-dialog
    v-model="previewDialogVisible"
    :title="t('migration.preview')"
    width="min(800px, 94vw)"
    :close-on-click-modal="false"
    top="5vh"
  >
    <template v-if="previewRunParams">
      <el-descriptions :column="1" border class="mb-4">
        <el-descriptions-item :label="t('migration.image')">
          <code>{{ previewRunParams.image || '-' }}</code>
        </el-descriptions-item>
        <el-descriptions-item :label="t('migration.container_name')">
          {{ previewRunParams.name || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="Network">
          {{ previewRunParams.network_mode || 'default' }}
        </el-descriptions-item>
        <el-descriptions-item :label="t('adopt.restart')">
          {{ previewRunParams.restart_policy || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="User">
          {{ previewRunParams.user || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="Privileged">
          {{ previewRunParams.privileged ? 'Yes' : 'No' }}
        </el-descriptions-item>
      </el-descriptions>

      <el-card v-if="previewEnvList().length > 0" class="mb-4" size="small">
        <template #header><span>{{ t('migration.environment') }}</span></template>
        <div class="text-xs font-mono leading-relaxed max-h-48 overflow-y-auto">
          <div v-for="e in previewEnvList()" :key="e.key" class="flex gap-2 py-0.5 border-b border-gray-100 last:border-0">
            <span class="text-gray-500 shrink-0">{{ e.key }}:</span>
            <span class="break-all whitespace-pre-wrap">{{ e.value }}</span>
          </div>
        </div>
      </el-card>

      <el-card v-if="previewPortList().length > 0" class="mb-4" size="small">
        <template #header><span>{{ t('migration.ports') }}</span></template>
        <div class="flex flex-wrap gap-2">
          <el-tag v-for="(p, i) in previewPortList()" :key="i" type="info" size="small">{{ p }}</el-tag>
        </div>
      </el-card>

      <el-card v-if="previewVolumeList().length > 0" class="mb-4" size="small">
        <template #header><span>{{ t('migration.volumes') }}</span></template>
        <div class="text-xs font-mono leading-relaxed">
          <div v-for="(v, i) in previewVolumeList()" :key="i" class="py-0.5">{{ v }}</div>
        </div>
      </el-card>

      <el-card v-if="previewRunParams.cap_add?.length || previewRunParams.cap_drop?.length" class="mb-4" size="small">
        <template #header><span>Capabilities</span></template>
        <div class="flex flex-wrap gap-2">
          <span v-if="previewRunParams.cap_add?.length" class="text-xs">
            <span class="text-gray-500 mr-1">Add:</span>
            <el-tag v-for="c in previewRunParams.cap_add" :key="c" size="small">{{ c }}</el-tag>
          </span>
          <span v-if="previewRunParams.cap_drop?.length" class="text-xs">
            <span class="text-gray-500 mr-1">Drop:</span>
            <el-tag v-for="c in previewRunParams.cap_drop" :key="c" type="danger" size="small">{{ c }}</el-tag>
          </span>
        </div>
      </el-card>

      <el-card v-if="previewRunParams.extra_hosts?.length" class="mb-4" size="small">
        <template #header><span>Extra Hosts</span></template>
        <div class="flex flex-wrap gap-2">
          <el-tag v-for="h in previewRunParams.extra_hosts" :key="h" size="small">{{ h }}</el-tag>
        </div>
      </el-card>
    </template>

    <template #footer>
      <div class="flex gap-3 justify-end">
        <el-button @click="previewDialogVisible = false">
          {{ t('common.back') }}
        </el-button>
        <el-button
          type="primary"
          :icon="Promotion"
          :loading="executing"
          @click="handleAdoptWithRebuild(true)"
        >
          {{ t('migration.confirm_execute') }}
        </el-button>
      </div>
    </template>
  </el-dialog>

  <!-- ===== Generate Template Dialog ===== -->
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

  <!-- ===== Quick Adopt Dialog ===== -->
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
      <el-button type="primary" :loading="adopting" @click="confirmQuickAdopt">
        {{ t('adopt.adopt') }}
      </el-button>
    </template>
  </el-dialog>
</template>
