<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useCurrentRemote } from '@/stores/currentRemote'
import { Connection } from '@element-plus/icons-vue'

const { t } = useI18n()
const remoteStore = useCurrentRemote()
const selected = ref('')
const busy = ref(true)

onMounted(async () => {
  if (!remoteStore.initialized) {
    await remoteStore.fetchRemotes()
  }
  busy.value = false
  if (remoteStore.current) {
    selected.value = remoteStore.current
  }
})

function confirm() {
  if (selected.value) {
    remoteStore.select(selected.value)
  }
}
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
    <div class="bg-white dark:bg-gray-800 rounded-xl shadow-2xl p-8 w-full max-w-md mx-4">
      <div class="text-center mb-6">
        <el-icon :size="48" color="#409eff"><Connection /></el-icon>
        <h2 class="text-xl font-semibold mt-3 dark:text-white">{{ t('remote.select') }}</h2>
        <p class="text-sm text-gray-500 mt-1 dark:text-gray-400">
          {{ t('app.desc') }}
        </p>
      </div>

      <div v-if="busy" class="text-center py-8">
        <el-icon class="is-loading" :size="32"><Connection /></el-icon>
        <p class="mt-2 text-sm text-gray-400">{{ t('remote.loading') }}</p>
      </div>

      <div v-else-if="remoteStore.remotes.length === 0" class="text-center py-4">
        <p class="text-gray-500 dark:text-gray-400">{{ t('common.no_data') }}</p>
      </div>

      <template v-else>
        <el-select
          v-model="selected"
          :placeholder="t('remote.select')"
          class="w-full"
          size="large"
        >
          <el-option
            v-for="r in remoteStore.remotes"
            :key="r.name"
            :label="r.name"
            :value="r.name"
          >
            <div class="flex items-center justify-between">
              <span>{{ r.name }}</span>
              <span v-if="r.default" class="text-xs text-yellow-500 ml-2">({{ t('remote.default') }})</span>
            </div>
          </el-option>
        </el-select>

        <div class="mt-6">
          <el-button
            type="primary"
            class="w-full"
            size="large"
            :disabled="!selected"
            @click="confirm"
          >
            {{ t('common.confirm') }}
          </el-button>
        </div>
      </template>
    </div>
  </div>
</template>
