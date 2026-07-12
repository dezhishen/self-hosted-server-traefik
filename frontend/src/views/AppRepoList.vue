<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { listAppRepos, addAppRepo, removeAppRepo, syncAppRepo } from '@/api/appRepos'
import type { AppRepo } from '@/api/appRepos'
import SdDialog from '@/components/SdDialog.vue'
import { Plus, Delete, Refresh } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const { t } = useI18n()
const repos = ref<AppRepo[]>([])
const loading = ref(false)
const dialogVisible = ref(false)
const saving = ref(false)
const newRepo = ref<Partial<AppRepo>>({
  name: '',
  url: '',
  enabled: true,
  auto_update: false
})

async function fetchRepos() {
  loading.value = true
  try {
    const res = await listAppRepos()
    repos.value = res.data
  } finally {
    loading.value = false
  }
}

function openAddDialog() {
  newRepo.value = { name: '', url: '', enabled: true, auto_update: false }
  dialogVisible.value = true
}

async function handleAdd() {
  if (!newRepo.value.name || !newRepo.value.url) return
  saving.value = true
  try {
    await addAppRepo(newRepo.value)
    ElMessage.success(t('common.success'))
    dialogVisible.value = false
    fetchRepos()
  } catch {
    // 错误由全局 errorHandler 注册链处理
  } finally {
    saving.value = false
  }
}

async function handleRemove(name: string) {
  try {
    await ElMessageBox.confirm(
      t('app_repos.remove') + ` "${name}"?`,
      t('common.confirm'),
      { confirmButtonText: t('common.delete'), cancelButtonText: t('common.close'), type: 'warning' }
    )
    await removeAppRepo(name)
    ElMessage.success(t('common.success'))
    fetchRepos()
  } catch {
  }
}

async function handleSync(name: string) {
  try {
    await syncAppRepo(name)
    ElMessage.success(t('common.success'))
  } catch {
  }
}

onMounted(fetchRepos)
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <h2>{{ t('app_repos.title') }}</h2>
    <el-button type="primary" :icon="Plus" @click="openAddDialog">{{ t('app_repos.add') }}</el-button>
  </div>

  <div class="table-responsive">
    <el-table :data="repos" stripe border size="small" v-loading="loading" style="width: 100%; min-width: 600px;">
    <el-table-column prop="name" :label="t('app_repos.name')" min-width="160" />
    <el-table-column prop="url" :label="t('app_repos.url')" min-width="300" show-overflow-tooltip />
    <el-table-column prop="enabled" :label="t('common.enabled') || 'Enabled'" width="100">
      <template #default="{ row }">
        <el-tag :type="row.enabled ? 'success' : 'info'" size="small">
          {{ row.enabled ? (t('common.yes') || 'Yes') : (t('common.no') || 'No') }}
        </el-tag>
      </template>
    </el-table-column>
    <el-table-column prop="auto_update" label="Auto Update" width="120">
      <template #default="{ row }">
        <el-tag :type="row.auto_update ? 'success' : 'info'" size="small">
          {{ row.auto_update ? (t('common.yes') || 'Yes') : (t('common.no') || 'No') }}
        </el-tag>
      </template>
    </el-table-column>
    <el-table-column :label="t('common.actions') || 'Actions'" width="200">
      <template #default="{ row }">
        <div class="flex gap-2">
          <el-button size="small" type="primary" plain :icon="Refresh" @click="handleSync(row.name)">
            {{ t('app_repos.sync') }}
          </el-button>
          <el-button size="small" type="danger" plain :icon="Delete" @click="handleRemove(row.name)">
            {{ t('app_repos.remove') }}
          </el-button>
        </div>
      </template>
    </el-table-column>
  </el-table>
  </div>

  <SdDialog
    :title="t('app_repos.add')"
    :visible="dialogVisible"
    :confirm-loading="saving"
    @update:visible="dialogVisible = $event"
    @confirm="handleAdd"
  >
    <el-form label-position="top">
      <el-form-item :label="t('app_repos.name')">
        <el-input v-model="newRepo.name" :placeholder="t('app_repos.name')" />
      </el-form-item>
      <el-form-item :label="t('app_repos.url')">
        <el-input v-model="newRepo.url" placeholder="https://example.com/repo" />
      </el-form-item>
      <el-form-item :label="t('common.enabled') || 'Enabled'">
        <el-switch v-model="newRepo.enabled!" />
      </el-form-item>
      <el-form-item label="Auto Update">
        <el-switch v-model="newRepo.auto_update!" />
      </el-form-item>
    </el-form>
  </SdDialog>
</template>
