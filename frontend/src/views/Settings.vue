<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getConfig, updateConfig } from '@/api/config'
import type { AppConfig } from '@/api/config'
import SdCard from '@/components/SdCard.vue'
import { ElMessage } from 'element-plus'

const config = ref<AppConfig | null>(null)
const loading = ref(false)
const saving = ref(false)

async function fetchConfig() {
  loading.value = true
  try {
    const res = await getConfig()
    config.value = res.data
  } finally {
    loading.value = false
  }
}

async function handleSave() {
  if (!config.value) return
  saving.value = true
  try {
    await updateConfig(config.value)
    ElMessage.success('Config saved')
  } catch {
    ElMessage.error('Failed to save config')
  } finally {
    saving.value = false
  }
}

function addEndpoint() {
  if (!config.value) return
  const name = prompt('Endpoint name:')
  if (!name) return
  config.value.endpoints[name] = {
    name,
    connection: { type: 'unix', endpoint: '/var/run/docker.sock' },
    default: Object.keys(config.value.endpoints).length === 0
  }
}

function removeEndpoint(name: string) {
  if (!config.value) return
  delete config.value.endpoints[name]
}

onMounted(fetchConfig)
</script>

<template>
  <div class="page-header flex items-center justify-between">
    <h2>Settings</h2>
    <el-button type="primary" :loading="saving" @click="handleSave">Save Config</el-button>
  </div>

  <div v-loading="loading">
    <el-row :gutter="20">
      <el-col :xs="24" :md="16">
        <SdCard>
          <template #header>
            <span class="font-semibold">Configuration</span>
          </template>

          <el-form label-position="top" v-if="config">
            <el-form-item label="Config Path">
              <el-input :model-value="config.base_data_dir" disabled />
            </el-form-item>

            <el-form-item label="Username">
              <el-input v-model="config.auth!.username" placeholder="admin" />
            </el-form-item>

            <el-divider>Endpoints</el-divider>

            <div v-for="(ep, name) in config.endpoints" :key="name" class="mb-4 p-4 border rounded">
              <div class="flex items-center justify-between mb-2">
                <strong>{{ name }}</strong>
                <div class="flex gap-2">
                  <el-tag v-if="ep.default" type="warning" size="small">default</el-tag>
                  <el-button size="small" type="danger" plain @click="removeEndpoint(name)">
                    Remove
                  </el-button>
                </div>
              </div>
              <el-form :model="ep" label-width="100px" size="small">
                <el-form-item label="Type">
                  <el-select v-model="ep.connection.type">
                    <el-option label="unix" value="unix" />
                    <el-option label="tcp" value="tcp" />
                  </el-select>
                </el-form-item>
                <el-form-item label="Endpoint">
                  <el-input v-model="ep.connection.endpoint" />
                </el-form-item>
                <el-form-item label="Engine">
                  <el-select v-model="ep.connection.engine" placeholder="auto">
                    <el-option label="auto" value="" />
                    <el-option label="docker" value="docker" />
                    <el-option label="podman" value="podman" />
                  </el-select>
                </el-form-item>
              </el-form>
            </div>

            <el-button type="primary" plain @click="addEndpoint">+ Add Endpoint</el-button>
          </el-form>
        </SdCard>
      </el-col>
    </el-row>
  </div>
</template>
