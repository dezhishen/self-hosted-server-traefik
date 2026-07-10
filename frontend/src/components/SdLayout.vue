<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useCurrentRemote } from '@/stores/currentRemote'
import SdSidebar from './SdSidebar.vue'
import RemoteSelect from './RemoteSelect.vue'
import { Operation } from '@element-plus/icons-vue'

const route = useRoute()
const remoteStore = useCurrentRemote()

const sidebarOpen = ref(false)

onMounted(() => {
  if (!remoteStore.initialized) {
    remoteStore.fetchRemotes()
  }
})

const breadcrumbMap: Record<string, string> = {
  Dashboard: 'Dashboard',
  ServiceList: 'Services',
  ServiceDetail: 'Service Detail',
  ParamList: 'Parameters',
  SubscriptionList: 'Subscriptions',
  RemoteList: 'Remote Hosts',
  Settings: 'Settings'
}

const breadcrumb = computed(() => breadcrumbMap[route.name as string] || '')

function toggleSidebar() {
  sidebarOpen.value = !sidebarOpen.value
}

function closeSidebar() {
  sidebarOpen.value = false
}
</script>

<template>
  <RemoteSelect v-if="remoteStore.initialized && !remoteStore.selected" />
  <div v-show="remoteStore.selected" class="flex min-h-screen">
    <SdSidebar :mobile-open="sidebarOpen" @close="closeSidebar" />
    <div class="flex-1 flex flex-col min-w-0" style="background-color: var(--content-bg);">
      <header
        class="flex items-center px-4 md:px-6 bg-white border-b border-gray-200 sticky top-0 z-30"
        style="height: var(--header-height);"
      >
        <el-button
          class="md:!hidden mr-3"
          :icon="Operation"
          size="small"
          text
          @click="toggleSidebar"
        />
        <el-breadcrumb separator="/" class="hidden md:flex">
          <el-breadcrumb-item :to="{ path: '/' }">Home</el-breadcrumb-item>
          <el-breadcrumb-item v-if="breadcrumb">{{ breadcrumb }}</el-breadcrumb-item>
        </el-breadcrumb>
        <el-breadcrumb separator="/" class="md:hidden text-sm">
          <el-breadcrumb-item v-if="breadcrumb">{{ breadcrumb }}</el-breadcrumb-item>
        </el-breadcrumb>
        <div class="ml-auto flex items-center gap-3">
          <el-tag type="info" size="small" effect="plain" class="hidden sm:inline-flex">v0.1.0</el-tag>
        </div>
      </header>
      <main class="flex-1 p-4 md:p-6 overflow-auto">
        <slot />
      </main>
    </div>
  </div>
</template>
