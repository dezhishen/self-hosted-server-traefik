<script setup lang="ts">
import { ref } from 'vue'
import SdCard from '@/components/SdCard.vue'

const isDark = ref(false)
const configPath = '/etc/selfhosted/config.yaml'

function toggleTheme() {
  isDark.value = !isDark.value
}
</script>

<template>
  <div class="page-header">
    <h2>Settings</h2>
  </div>

  <el-row :gutter="20">
    <el-col :span="12">
      <SdCard>
        <template #header>
          <span class="font-semibold">Configuration</span>
        </template>
        <el-descriptions :column="1" border>
          <el-descriptions-item label="Config File Path">
            <code class="text-sm bg-gray-100 px-2 py-0.5 rounded">{{ configPath }}</code>
          </el-descriptions-item>
        </el-descriptions>
      </SdCard>

      <SdCard class="mt-4">
        <template #header>
          <span class="font-semibold">Appearance</span>
        </template>
        <div class="flex items-center justify-between">
          <div>
            <p class="font-medium m-0">Theme</p>
            <p class="text-sm text-gray-500 m-0 mt-1">Switch between light and dark mode</p>
          </div>
          <el-switch
            v-model="isDark"
            active-text="Dark"
            inactive-text="Light"
            @change="toggleTheme"
          />
        </div>
      </SdCard>
    </el-col>

    <el-col :span="12">
      <SdCard>
        <template #header>
          <span class="font-semibold">About</span>
        </template>
        <el-descriptions :column="1" border>
          <el-descriptions-item label="Version">0.1.0</el-descriptions-item>
          <el-descriptions-item label="Frontend">Vue 3 + Element Plus</el-descriptions-item>
          <el-descriptions-item label="Backend">Go</el-descriptions-item>
        </el-descriptions>
      </SdCard>
    </el-col>
  </el-row>
</template>
