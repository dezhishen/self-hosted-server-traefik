<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { analyzeMigrations, executeMigration } from '@/api/migrate'
import type { MigrationCandidate, MigrationRequest } from '@/api/migrate'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Promotion, View } from '@element-plus/icons-vue'

const { t } = useI18n()

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

function updateParam(index: number, value: unknown) {
  if (selected.value && selected.value.extracted_params) {
    selected.value.extracted_params[index].value = value
  }
}

onMounted(fetchCandidates)
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <h2>{{ t('nav.migration') }}</h2>
    <el-button :icon="Promotion" @click="fetchCandidates" :disabled="loading">
      {{ t('common.refresh') }}
    </el-button>
  </div>

  <template v-if="step === 'list'">
    <div class="table-responsive">
      <el-table :data="candidates" stripe border v-loading="loading" style="width: 100%; min-width: 700px;">
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

    <div class="mt-6">
      <el-button
        type="primary"
        :icon="Promotion"
        :loading="executing"
        :disabled="!selected.matched_service"
        @click="handleMigrate"
      >
        {{ t('migration.migrate') }}
      </el-button>
    </div>
  </template>
</template>
