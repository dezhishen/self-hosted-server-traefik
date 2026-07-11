<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { getConfig, updateConfig, sshKeygen, sshKeyImport, changePassword } from '@/api/config'
import type { AppConfig, TLSConfig, SSHKeygenResult } from '@/api/config'
import SdCard from '@/components/SdCard.vue'
import { ElMessage } from 'element-plus'

const { t } = useI18n()

const config = ref<AppConfig | null>(null)
const loading = ref(false)
const saving = ref(false)
const passwordSaving = ref(false)
const newPassword = ref('')
const confirmPassword = ref('')

// SSH keygen state
const keygenEndpointName = ref('')
const keygenDialogVisible = ref(false)
const keygenLoading = ref(false)
const keygenName = ref('')
const keygenType = ref('ed25519')
const keygenResult = ref<SSHKeygenResult | null>(null)
const keygenStep = ref<'form' | 'result'>('form')
// Cache key info per endpoint for immediate display after keygen
const endpointKeyMap = ref<Record<string, SSHKeygenResult>>({})

// SSH import state
const importDialogVisible = ref(false)
const importEndpointName = ref('')
const importPrivateKey = ref('')
const importLoading = ref(false)

function getEPKeyInfo(name: string) {
  const ep = config.value?.endpoints[name]
  if (!ep) return null
  // Try cache first, then config response
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
    // 错误由全局 errorHandler 注册链处理
  } finally {
    saving.value = false
  }
}

async function handlePasswordSave() {
  if (!newPassword.value) {
    ElMessage.warning('Please enter a new password')
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    ElMessage.warning(t('settings.password_mismatch'))
    return
  }
  passwordSaving.value = true
  try {
    await changePassword(newPassword.value)
    ElMessage.success(t('settings.password_updated'))
    newPassword.value = ''
    confirmPassword.value = ''
  } catch {
    // 错误由全局 errorHandler 注册链处理
  } finally {
    passwordSaving.value = false
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
    ElMessage.warning('Please enter a key name')
    return
  }
  keygenLoading.value = true
  try {
    const res = await sshKeygen(keygenEndpointName.value, keygenName.value.trim(), keygenType.value)
    // Private key is stored server-side - never received by frontend
    endpointKeyMap.value[keygenEndpointName.value] = res.data
    keygenResult.value = res.data
    keygenStep.value = 'result'
  } catch {
    // 错误由全局 errorHandler 注册链处理
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
  ElMessage.success('Public key copied')
}

// --- SSH Key Import ---
function openImportForEndpoint(name: string) {
  importEndpointName.value = name
  importPrivateKey.value = ''
  importDialogVisible.value = true
}

async function handleImport() {
  if (!importPrivateKey.value.trim()) {
    ElMessage.warning('Please paste your private key')
    return
  }
  importLoading.value = true
  try {
    const res = await sshKeyImport(importEndpointName.value, importPrivateKey.value)
    endpointKeyMap.value[importEndpointName.value] = res.data
    importDialogVisible.value = false
    ElMessage.success('Private key imported')
  } catch {
    // 错误由全局 errorHandler 注册链处理
  } finally {
    importLoading.value = false
  }
}

onMounted(fetchConfig)
</script>

<template>
  <div class="page-header flex items-center justify-between flex-wrap gap-2">
    <h2>{{ t('settings.title') }}</h2>
    <el-button type="primary" size="small" :loading="saving" @click="handleSave">{{ t('settings.save') }}</el-button>
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
              <div class="flex items-start sm:items-center justify-between mb-2 flex-col sm:flex-row gap-2">
                <strong>{{ name }}</strong>
                <div class="flex gap-2 flex-wrap">
                  <el-tag v-if="ep.default" type="warning" size="small">default</el-tag>
                  <el-button size="small" type="danger" plain @click="removeEndpoint(name)">
                    Remove
                  </el-button>
                </div>
              </div>
              <el-form :model="ep" label-width="110px" size="small" label-position="left">
                <el-form-item label="Type">
                  <el-select v-model="ep.connection.type" @change="initTLS(ep as any)">
                    <el-option label="unix" value="unix" />
                    <el-option label="tcp" value="tcp" />
                    <el-option label="http" value="http" />
                    <el-option label="https" value="https" />
                    <el-option label="ssh" value="ssh" />
                  </el-select>
                </el-form-item>
                <el-form-item label="Endpoint">
                  <el-input v-model="ep.connection.endpoint" placeholder="/var/run/docker.sock or host:port" />
                </el-form-item>
                <el-form-item label="Engine">
                  <el-select v-model="ep.connection.engine" placeholder="auto">
                    <el-option label="auto" value="" />
                    <el-option label="docker" value="docker" />
                    <el-option label="podman" value="podman" />
                  </el-select>
                </el-form-item>

                <template v-if="showSSH(ep.connection.type)">
                  <el-divider />
                  <el-form-item label="SSH User">
                    <el-input v-model="ep.connection.ssh_user" placeholder="root" />
                  </el-form-item>

                  <!-- SSH Key Management: generate or import -->
                    <el-form-item label="SSH Key">
                    <div class="flex flex-col gap-2 w-full">
                      <div v-if="getEPKeyInfo(name)" class="flex items-center gap-2 flex-wrap">
                        <el-tag type="info" size="small">configured</el-tag>
                        <span class="text-xs text-gray-500">
                          Private key is stored server-side
                        </span>
                      </div>
                      <div v-else class="text-xs text-gray-500">
                        No SSH key configured. Generate a new key pair or import an existing one.
                      </div>
                      <div class="flex gap-2 flex-wrap w-full sm:flex-nowrap">
                        <el-button size="small" class="flex-1 sm:flex-none" @click="openKeygenForEndpoint(name)">
                          {{ getEPKeyInfo(name) ? 'Regenerate' : 'Generate SSH Key' }}
                        </el-button>
                        <el-button size="small" plain class="flex-1 sm:flex-none" @click="openImportForEndpoint(name)">
                          Import Key
                        </el-button>
                      </div>
                    </div>
                  </el-form-item>

                  <!-- Public key info (derived from server-side private key) -->
                  <template v-if="getEPKeyInfo(name)">
                    <el-form-item label="Key Type">
                      <el-tag size="small" type="success">{{ getEPKeyInfo(name)!.type }}</el-tag>
                    </el-form-item>
                    <el-form-item label="Fingerprint">
                      <span class="text-sm font-mono">{{ getEPKeyInfo(name)!.fingerprint }}</span>
                    </el-form-item>
                    <el-form-item label="Public Key">
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
                          Copy
                        </el-button>
                      </div>
                      <p class="text-xs text-gray-500 mt-1">
                        Add this public key to <code>~/.ssh/authorized_keys</code> on the remote server
                      </p>
                    </el-form-item>
                  </template>
                </template>

                <template v-if="showTLS(ep.connection.type)">
                  <el-divider />
                  <el-form-item label="TLS">
                    <el-switch v-model="ep.connection.tls!.enabled" />
                  </el-form-item>

                  <template v-if="ep.connection.tls?.enabled">
                    <el-form-item label="CA Cert">
                      <el-input v-model="ep.connection.tls.ca_cert" type="textarea" :rows="2" placeholder="PEM content" />
                    </el-form-item>
                    <el-form-item label="Client Cert">
                      <el-input v-model="ep.connection.tls.cert" type="textarea" :rows="2" placeholder="PEM content" />
                    </el-form-item>
                    <el-form-item label="Client Key">
                      <el-input v-model="ep.connection.tls.key" type="textarea" :rows="2" placeholder="PEM content" />
                    </el-form-item>
                    <el-form-item label="Skip Verify">
                      <el-switch v-model="ep.connection.tls.skip_verify!" />
                    </el-form-item>
                  </template>
                </template>
              </el-form>
              <div class="flex justify-end mt-3 pt-3 border-t">
                <el-button size="small" type="primary" :loading="saving" @click="handleSave">
                  Save Endpoint
                </el-button>
              </div>
            </div>

            <div class="flex items-center gap-2 mt-4">
              <el-button type="primary" plain @click="addEndpoint">+ Add Endpoint</el-button>
              <el-button type="primary" :loading="saving" @click="handleSave">Save All Changes</el-button>
            </div>
          </el-form>
        </SdCard>

        <!-- Password Card -->
        <SdCard class="mt-4">
          <template #header>
            <span class="font-semibold">Change Password</span>
          </template>
          <el-form label-position="top">
            <el-form-item label="New Password">
              <el-input
                v-model="newPassword"
                type="password"
                placeholder="Enter new password"
                show-password
              />
            </el-form-item>
            <el-form-item label="Confirm Password">
              <el-input
                v-model="confirmPassword"
                type="password"
                placeholder="Confirm new password"
                show-password
              />
            </el-form-item>
            <el-button type="primary" :loading="passwordSaving" @click="handlePasswordSave">
              Update Password
            </el-button>
          </el-form>
        </SdCard>
      </el-col>
    </el-row>
  </div>

  <!-- SSH Keygen Dialog: form -> result (public key only) -->
  <el-dialog
    v-model="keygenDialogVisible"
    :title="keygenStep === 'form' ? 'Generate SSH Key' : 'SSH Key Generated'"
    width="600px"
    :close-on-click-modal="false"
    @close="closeKeygen"
  >
    <!-- Step 1: Key generation form -->
    <template v-if="keygenStep === 'form'">
      <el-form label-position="top">
        <el-form-item label="Key Name" required>
          <el-input v-model="keygenName" placeholder="e.g. my-server-key" />
        </el-form-item>
        <el-form-item label="Key Type">
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
        <el-button @click="closeKeygen">Cancel</el-button>
        <el-button type="primary" :loading="keygenLoading" @click="handleKeygen">
          Generate
        </el-button>
      </div>
    </template>

    <!-- Step 2: Show public key only (private key stored server-side) -->
    <template v-else-if="keygenResult">
      <div class="space-y-4">
        <el-alert
          type="success"
          :title="`${keygenResult.type} key generated — ${keygenResult.fingerprint}`"
          :closable="false"
          show-icon
        />
        <div>
          <label class="text-sm font-semibold block mb-1">Public Key</label>
          <p class="text-xs text-gray-500 mb-2">
            Add this public key to the remote server's <code>~/.ssh/authorized_keys</code>.
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
              Copy
            </el-button>
          </div>
        </div>
      </div>
      <div class="text-right mt-4">
        <el-button type="primary" @click="closeKeygen">Done</el-button>
      </div>
    </template>
  </el-dialog>

  <!-- SSH Key Import Dialog -->
  <el-dialog
    v-model="importDialogVisible"
    title="Import SSH Private Key"
    width="600px"
    :close-on-click-modal="false"
  >
    <p class="text-sm text-gray-500 mb-3">
      Paste your existing SSH private key. The key will be stored server-side
      and <strong>never returned</strong> to the browser.
    </p>
    <el-input
      v-model="importPrivateKey"
      type="textarea"
      :rows="6"
      placeholder="-----BEGIN OPENSSH PRIVATE KEY-----&#10;..."
    />
    <div class="text-right mt-4">
      <el-button @click="importDialogVisible = false">Cancel</el-button>
      <el-button type="primary" :loading="importLoading" @click="handleImport">
        Import
      </el-button>
    </div>
  </el-dialog>
</template>

<style scoped>
</style>
