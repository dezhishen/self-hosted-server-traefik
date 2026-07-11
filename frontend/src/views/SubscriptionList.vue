<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { listSubscriptions, addSubscription, removeSubscription, syncSubscription } from '@/api/subscriptions'
import type { Subscription } from '@/api/subscriptions'
import SdDialog from '@/components/SdDialog.vue'
import { Plus, Delete, Refresh } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const { t } = useI18n()
const subscriptions = ref<Subscription[]>([])
const loading = ref(false)
const dialogVisible = ref(false)
const saving = ref(false)
const newSub = ref<Partial<Subscription>>({
  name: '',
  url: '',
  enabled: true,
  auto_update: false
})

async function fetchSubscriptions() {
  loading.value = true
  try {
    const res = await listSubscriptions()
    subscriptions.value = res.data
  } finally {
    loading.value = false
  }
}

function openAddDialog() {
  newSub.value = { name: '', url: '', enabled: true, auto_update: false }
  dialogVisible.value = true
}

async function handleAdd() {
  if (!newSub.value.name || !newSub.value.url) return
  saving.value = true
  try {
    await addSubscription(newSub.value)
    ElMessage.success(t('common.success'))
    dialogVisible.value = false
    fetchSubscriptions()
  } catch {
    // 错误由全局 errorHandler 注册链处理
  } finally {
    saving.value = false
  }
}

async function handleRemove(name: string) {
  try {
    await ElMessageBox.confirm(
      t('subscriptions.remove') + ` "${name}"?`,
      t('common.confirm'),
      { confirmButtonText: t('common.delete'), cancelButtonText: t('common.close'), type: 'warning' }
    )
    await removeSubscription(name)
    ElMessage.success(t('common.success'))
    fetchSubscriptions()
  } catch {
  }
}

async function handleSync(name: string) {
  try {
    await syncSubscription(name)
    ElMessage.success(t('common.success'))
  } catch {
  }
}

onMounted(fetchSubscriptions)
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <h2>{{ t('subscriptions.title') }}</h2>
    <el-button type="primary" :icon="Plus" @click="openAddDialog">{{ t('subscriptions.add') }}</el-button>
  </div>

  <div class="table-responsive">
    <el-table :data="subscriptions" stripe border v-loading="loading" style="width: 100%; min-width: 600px;">
    <el-table-column prop="name" :label="t('subscriptions.name')" min-width="160" />
    <el-table-column prop="url" :label="t('subscriptions.url')" min-width="300" show-overflow-tooltip />
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
            {{ t('subscriptions.sync') }}
          </el-button>
          <el-button size="small" type="danger" plain :icon="Delete" @click="handleRemove(row.name)">
            {{ t('subscriptions.remove') }}
          </el-button>
        </div>
      </template>
    </el-table-column>
  </el-table>
  </div>

  <SdDialog
    :title="t('subscriptions.add')"
    :visible="dialogVisible"
    :confirm-loading="saving"
    @update:visible="dialogVisible = $event"
    @confirm="handleAdd"
  >
    <el-form label-position="top">
      <el-form-item :label="t('subscriptions.name')">
        <el-input v-model="newSub.name" :placeholder="t('subscriptions.name')" />
      </el-form-item>
      <el-form-item :label="t('subscriptions.url')">
        <el-input v-model="newSub.url" placeholder="https://example.com/repo" />
      </el-form-item>
      <el-form-item :label="t('common.enabled') || 'Enabled'">
        <el-switch v-model="newSub.enabled!" />
      </el-form-item>
      <el-form-item label="Auto Update">
        <el-switch v-model="newSub.auto_update!" />
      </el-form-item>
    </el-form>
  </SdDialog>
</template>
