<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { listSubscriptions, addSubscription, removeSubscription, syncSubscription } from '@/api/subscriptions'
import type { Subscription } from '@/api/subscriptions'
import SdDialog from '@/components/SdDialog.vue'
import { Plus, Delete, Refresh } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'

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
    ElMessage.success('Subscription added')
    dialogVisible.value = false
    fetchSubscriptions()
  } finally {
    saving.value = false
  }
}

async function handleRemove(name: string) {
  try {
    await ElMessageBox.confirm(
      `Remove subscription "${name}"?`,
      'Confirm Remove',
      { confirmButtonText: 'Remove', cancelButtonText: 'Cancel', type: 'warning' }
    )
    await removeSubscription(name)
    ElMessage.success('Subscription removed')
    fetchSubscriptions()
  } catch {
  }
}

async function handleSync(name: string) {
  try {
    await syncSubscription(name)
    ElMessage.success('Sync initiated')
  } catch {
  }
}

onMounted(fetchSubscriptions)
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <h2>Subscriptions</h2>
    <el-button type="primary" :icon="Plus" @click="openAddDialog">Add Subscription</el-button>
  </div>

  <el-table :data="subscriptions" stripe border v-loading="loading" style="width: 100%">
    <el-table-column prop="name" label="Name" min-width="160" />
    <el-table-column prop="url" label="URL" min-width="300" show-overflow-tooltip />
    <el-table-column prop="enabled" label="Enabled" width="100">
      <template #default="{ row }">
        <el-tag :type="row.enabled ? 'success' : 'info'" size="small">
          {{ row.enabled ? 'Yes' : 'No' }}
        </el-tag>
      </template>
    </el-table-column>
    <el-table-column prop="auto_update" label="Auto Update" width="120">
      <template #default="{ row }">
        <el-tag :type="row.auto_update ? 'success' : 'info'" size="small">
          {{ row.auto_update ? 'Yes' : 'No' }}
        </el-tag>
      </template>
    </el-table-column>
    <el-table-column label="Actions" width="200" fixed="right">
      <template #default="{ row }">
        <div class="flex gap-2">
          <el-button size="small" type="primary" plain :icon="Refresh" @click="handleSync(row.name)">
            Sync
          </el-button>
          <el-button size="small" type="danger" plain :icon="Delete" @click="handleRemove(row.name)">
            Remove
          </el-button>
        </div>
      </template>
    </el-table-column>
  </el-table>

  <SdDialog
    title="Add Subscription"
    :visible="dialogVisible"
    :confirm-loading="saving"
    @update:visible="dialogVisible = $event"
    @confirm="handleAdd"
  >
    <el-form label-position="top">
      <el-form-item label="Name">
        <el-input v-model="newSub.name" placeholder="Subscription name" />
      </el-form-item>
      <el-form-item label="URL">
        <el-input v-model="newSub.url" placeholder="https://example.com/repo" />
      </el-form-item>
      <el-form-item label="Enabled">
        <el-switch v-model="newSub.enabled!" />
      </el-form-item>
      <el-form-item label="Auto Update">
        <el-switch v-model="newSub.auto_update!" />
      </el-form-item>
    </el-form>
  </SdDialog>
</template>
