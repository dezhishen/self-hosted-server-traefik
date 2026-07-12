<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { getConfig, updateConfig, sshKeygen, sshKeyImport, sshAuthorize } from '@/api/config'
import type { AppConfig, TLSConfig, SSHKeygenResult } from '@/api/config'
import SdCard from '@/components/SdCard.vue'
import { ElMessage } from 'element-plus'

const { t } = useI18n()

const config = ref<AppConfig | null>(null)
const loading = ref(false)
const saving = ref(false)

// SSH keygen state
const keygenEndpointName = ref('')
const keygenDialogVisible = ref(false)
const keygenLoading = ref(false)
const keygenName = ref('')
const keygenType = ref('ed25519')
const keygenResult = ref<SSHKeygenResult | null>(null)
const keygenStep = ref<'form' | 'result'>('form')
const endpointKeyMap = ref<Record<string, SSHKeygenResult>>({})

// SSH import state
const importDialogVisible = ref(false)
const importEndpointName = ref('')
const importPrivateKey = ref('')
const importLoading = ref(false)

// SSH authorize state
const authorizeDialogVisible = ref(false)
const authorizeEndpointName = ref('')
const authorizePassword = ref('')
const authorizeLoading = ref(false)

function getEPKeyInfo(name: string) {
  const ep = config.value?.endpoints[name]
  if (!ep) return null
  if (endpointKeyMap.value[name]) return endpointKeyMap.value[name]
  if (ep.connection.ssh_public_key) {
    return {
      name,
      key_name: '',
      public_key: ep.connection.ssh_public_key,
      fingerprint: ep.connection.ssh_key_fingerprint || '',
      type: ep.connection.ssh_key_type || ''
    } as SSHKeygenResult
  }
  return null
}

async function fetchConfig() {
  loading.value = true
  try {
    const res = await getConfig()
    for (const ep of Object.values(res.data.endpoints)) {
      if (ep.connection.type === 'https' && !ep.connection.tls) {
        ep.connection.tls = { enabled: true }
      }
      if (ep.connection.type === 'tcp' && !ep.connection.tls) {
        ep.connection.tls = { enabled: false }
      }
    }
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
    ElMessage.success(t('common.success'))
  } catch {
    // error handled by global errorHandler
  } finally {
    saving.value = false
  }
}

function addEndpoint() {
  if (!config.value) return
  const name = prompt(t('settings.msg_endpoint_name'))
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
  delete endpointKeyMap.value[name]
}

function initTLS(ep: { connection: { type: string; tls?: TLSConfig } }) {
  if (showTLS(ep.connection.type) && !ep.connection.tls) {
    ep.connection.tls = { enabled: true }
  }
}

function showTLS(type: string) {
  return type === 'tcp' || type === 'https'
}

function showSSH(type: string) {
  return type === 'ssh'
}

// --- SSH Key Generation ---
function openKeygenForEndpoint(name: string) {
  keygenEndpointName.value = name
  keygenName.value = name + '-key'
  keygenType.value = 'ed25519'
  keygenResult.value = null
  keygenStep.value = 'form'
  keygenDialogVisible.value = true
}

async function handleKeygen() {
  if (!keygenName.value.trim()) {
    ElMessage.warning(t('settings.msg_key_name_required'))
    return
  }
  keygenLoading.value = true
  try {
    const res = await sshKeygen(keygenEndpointName.value, keygenName.value.trim(), keygenType.value)
    endpointKeyMap.value[keygenEndpointName.value] = res.data
    keygenResult.value = res.data
    keygenStep.value = 'result'
  } catch {
    // error handled by global errorHandler
  } finally {
    keygenLoading.value = false
  }
}

function closeKeygen() {
  keygenDialogVisible.value = false
  keygenResult.value = null
  keygenStep.value = 'form'
}

function copyPublicKey(key: string) {
  navigator.clipboard.writeText(key)
  ElMessage.success(t('settings.msg_key_copied'))
}

// --- SSH Key Import ---
function openImportForEndpoint(name: string) {
  importEndpointName.value = name
  importPrivateKey.value = ''
  importDialogVisible.value = true
}

async function handleImport() {
  if (!importPrivateKey.value.trim()) {
    ElMessage.warning(t('settings.msg_key_paste_required'))
    return
  }
  importLoading.value = true
  try {
    const res = await sshKeyImport(importEndpointName.value, importPrivateKey.value)
    endpointKeyMap.value[importEndpointName.value] = res.data
    importDialogVisible.value = false
    ElMessage.success(t('settings.msg_key_imported'))
  } catch {
    // error handled by global errorHandler
  } finally {
    importLoading.value = false
  }
}

// --- SSH Authorize ---
function openAuthorize(name: string) {
  authorizeEndpointName.value = name
  authorizePassword.value = ''
  authorizeDialogVisible.value = true
}

async function handleAuthorize() {
  if (!authorizePassword.value.trim()) {
    ElMessage.warning(t('settings.msg_password_required'))
    return
  }
  authorizeLoading.value = true
  try {
    await sshAuthorize(authorizeEndpointName.value, authorizePassword.value)
    ElMessage.success(t('settings.msg_authorized'))
    authorizeDialogVisible.value = false
  } catch {
    // error handled by global errorHandler
  } finally {
    authorizeLoading.value = false
  }
}

onMounted(fetchConfig)
</script>

<template>
  <div class="page-header flex items-center justify-between flex-wrap gap-2">
    <h2>{{ t('settings.endpoints') }}</h2>
  </div>

  <div v-loading="loading">
    <div v-if="config">
      <div v-for="(ep, name) in config.endpoints" :key="name" class="mb-4">
        <SdCard>
          <template #header>
            <div class="flex items-start sm:items-center justify-between flex-col sm:flex-row gap-2">
              <strong>{{ name }}</strong>
              <div class="flex gap-2 flex-wrap">
                <el-tag v-if="ep.default" type="warning" size="small">{{ t('settings.default') }}</el-tag>
                <el-button size="small" type="danger" plain @click="removeEndpoint(name)">
                  {{ t('settings.remove') }}
                </el-button>
              </div>
            </div>
          </template>
          <el-form :model="ep" label-width="110px" size="small" label-position="left">
            <el-form-item :label="t('settings.type')">
              <el-select v-model="ep.connection.type" @change="initTLS(ep as any)">
                <el-option :label="t('settings.type_unix')" value="unix" />
                <el-option :label="t('settings.type_tcp')" value="tcp" />
                <el-option :label="t('settings.type_http')" value="http" />
                <el-option :label="t('settings.type_https')" value="https" />
                <el-option :label="t('settings.type_ssh')" value="ssh" />
              </el-select>
            </el-form-item>
            <el-form-item :label="t('settings.endpoint')">
              <el-input v-model="ep.connection.endpoint" :placeholder="t('settings.endpoint_placeholder')" />
            </el-form-item>
            <el-form-item :label="t('settings.engine')">
              <el-select v-model="ep.connection.engine" :placeholder="t('settings.engine_auto')">
                <el-option :label="t('settings.engine_auto')" value="" />
                <el-option :label="t('settings.engine_docker')" value="docker" />
                <el-option :label="t('settings.engine_podman')" value="podman" />
              </el-select>
            </el-form-item>

            <template v-if="showSSH(ep.connection.type)">
              <el-divider />
              <el-form-item :label="t('settings.ssh_user')">
                <el-input v-model="ep.connection.ssh_user" :placeholder="t('settings.ssh_user_placeholder')" />
              </el-form-item>

              <el-form-item :label="t('settings.ssh_key')">
                <div class="flex flex-col gap-2 w-full">
                  <div v-if="getEPKeyInfo(name)" class="flex items-center gap-2 flex-wrap">
                    <el-tag type="info" size="small">{{ t('settings.configured') }}</el-tag>
                    <span class="text-xs text-gray-500">
                      {{ t('settings.ssh_key_stored') }}
                    </span>
                  </div>
                  <div v-else class="text-xs text-gray-500">
                    {{ t('settings.ssh_no_key') }}
                  </div>
                  <div class="flex gap-2 flex-wrap w-full sm:flex-nowrap">
                    <el-button size="small" class="flex-1 sm:flex-none" @click="openKeygenForEndpoint(name)">
                      {{ getEPKeyInfo(name) ? t('settings.ssh_regenerate') : t('settings.ssh_generate') }}
                    </el-button>
                    <el-button size="small" plain class="flex-1 sm:flex-none" @click="openImportForEndpoint(name)">
                      {{ t('settings.ssh_import_key') }}
                    </el-button>
                  </div>
                </div>
              </el-form-item>

              <template v-if="getEPKeyInfo(name)">
                <el-form-item :label="t('settings.key_type')">
                  <el-tag size="small" type="success">{{ getEPKeyInfo(name)!.type }}</el-tag>
                </el-form-item>
                <el-form-item :label="t('settings.fingerprint')">
                  <span class="text-sm font-mono">{{ getEPKeyInfo(name)!.fingerprint }}</span>
                </el-form-item>
                <el-form-item :label="t('settings.public_key')">
                  <div class="relative w-full">
                    <el-input
                      :model-value="getEPKeyInfo(name)!.public_key"
                      type="textarea"
                      :rows="2"
                      readonly
                    />
                    <el-button
                      class="absolute top-1 right-1"
                      size="small"
                      @click="copyPublicKey(getEPKeyInfo(name)!.public_key)"
                    >
                      {{ t('settings.copy') }}
                    </el-button>
                  </div>
                  <p class="text-xs text-gray-500 mt-1">
                    {{ t('settings.public_key_hint') }}
                  </p>
                </el-form-item>
                <el-form-item>
                  <el-button
                    size="small"
                    type="primary"
                    @click="openAuthorize(name)"
                  >
                    {{ t('settings.authorize_remote') }}
                  </el-button>
                  <span class="text-xs text-gray-500 ml-2">{{ t('settings.authorize_hint') }}</span>
                </el-form-item>
              </template>
            </template>

            <template v-if="showTLS(ep.connection.type)">
              <el-divider />
              <el-form-item :label="t('settings.tls')">
                <el-switch v-model="ep.connection.tls!.enabled" />
              </el-form-item>

              <template v-if="ep.connection.tls?.enabled">
                <el-form-item :label="t('settings.ca_cert')">
                  <el-input v-model="ep.connection.tls.ca_cert" type="textarea" :rows="2" :placeholder="t('settings.pem_placeholder')" />
                </el-form-item>
                <el-form-item :label="t('settings.client_cert')">
                  <el-input v-model="ep.connection.tls.cert" type="textarea" :rows="2" :placeholder="t('settings.pem_placeholder')" />
                </el-form-item>
                <el-form-item :label="t('settings.client_key')">
                  <el-input v-model="ep.connection.tls.key" type="textarea" :rows="2" :placeholder="t('settings.pem_placeholder')" />
                </el-form-item>
                <el-form-item :label="t('settings.skip_verify')">
                  <el-switch v-model="ep.connection.tls.skip_verify!" />
                </el-form-item>
              </template>
            </template>
          </el-form>
        </SdCard>
      </div>

      <div v-if="Object.keys(config.endpoints).length === 0" class="text-center text-gray-400 py-12">
        {{ t('common.no_data') }}
      </div>

      <div class="flex items-center gap-2 mt-4">
        <el-button type="primary" plain @click="addEndpoint">{{ t('settings.add_endpoint') }}</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">{{ t('settings.save_all') }}</el-button>
      </div>
    </div>
  </div>

  <!-- SSH Keygen Dialog -->
  <el-dialog
    v-model="keygenDialogVisible"
    :title="keygenStep === 'form' ? t('settings.keygen_title') : t('settings.keygen_result_title')"
    :width="'min(600px, 92vw)'"
    :close-on-click-modal="false"
    @close="closeKeygen"
  >
    <template v-if="keygenStep === 'form'">
      <el-form label-position="top">
        <el-form-item :label="t('settings.key_name')" required>
          <el-input v-model="keygenName" :placeholder="t('settings.key_name_placeholder')" />
        </el-form-item>
        <el-form-item :label="t('settings.key_type_select')">
          <el-select v-model="keygenType">
            <el-option label="Ed25519 (recommended)" value="ed25519" />
            <el-option label="RSA 2048" value="rsa-2048" />
            <el-option label="RSA 4096" value="rsa-4096" />
            <el-option label="ECDSA P-256" value="ecdsa-p256" />
            <el-option label="ECDSA P-384" value="ecdsa-p384" />
          </el-select>
        </el-form-item>
      </el-form>
      <div class="text-right">
        <el-button @click="closeKeygen">{{ t('settings.cancel') }}</el-button>
        <el-button type="primary" :loading="keygenLoading" @click="handleKeygen">
          {{ t('settings.generate') }}
        </el-button>
      </div>
    </template>

    <template v-else-if="keygenResult">
      <div class="space-y-4">
        <el-alert
          type="success"
          :title="t('settings.keygen_success', { type: keygenResult.type, fingerprint: keygenResult.fingerprint })"
          :closable="false"
          show-icon
        />
        <div>
          <label class="text-sm font-semibold block mb-1">{{ t('settings.public_key') }}</label>
          <p class="text-xs text-gray-500 mb-2">
            {{ t('settings.public_key_hint') }}
          </p>
          <div class="relative">
            <el-input
              :model-value="keygenResult.public_key"
              type="textarea"
              :rows="3"
              readonly
            />
            <el-button
              class="absolute top-1 right-1"
              size="small"
              @click="copyPublicKey(keygenResult.public_key)"
            >
              {{ t('settings.copy') }}
            </el-button>
          </div>
        </div>
      </div>
      <div class="text-right mt-4">
        <el-button type="primary" @click="closeKeygen">{{ t('settings.done') }}</el-button>
      </div>
    </template>
  </el-dialog>

  <!-- SSH Key Import Dialog -->
  <el-dialog
    v-model="importDialogVisible"
    :title="t('settings.import_title')"
    :width="'min(600px, 92vw)'"
    :close-on-click-modal="false"
  >
    <p class="text-sm text-gray-500 mb-3">
      {{ t('settings.import_desc') }}
    </p>
    <el-input
      v-model="importPrivateKey"
      type="textarea"
      :rows="6"
      :placeholder="t('settings.import_placeholder')"
    />
    <div class="text-right mt-4">
      <el-button @click="importDialogVisible = false">{{ t('settings.cancel') }}</el-button>
      <el-button type="primary" :loading="importLoading" @click="handleImport">
        {{ t('settings.import') }}
      </el-button>
    </div>
  </el-dialog>

  <!-- SSH Authorize Dialog -->
  <el-dialog
    v-model="authorizeDialogVisible"
    :title="t('settings.authorize_title')"
    :width="'min(400px, 90vw)'"
    :close-on-click-modal="false"
  >
    <p class="text-sm text-gray-500 mb-3">
      {{ t('settings.authorize_desc', { name: authorizeEndpointName }) }}
    </p>
    <el-input
      v-model="authorizePassword"
      type="password"
      :placeholder="t('settings.authorize_password_placeholder')"
      show-password
      @keyup.enter="handleAuthorize"
    />
    <div class="text-right mt-4">
      <el-button @click="authorizeDialogVisible = false">{{ t('settings.cancel') }}</el-button>
      <el-button type="primary" :loading="authorizeLoading" @click="handleAuthorize">
        {{ t('settings.authorize_confirm') }}
      </el-button>
    </div>
  </el-dialog>
</template>
