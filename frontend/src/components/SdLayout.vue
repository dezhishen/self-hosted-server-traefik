<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useCurrentRemote } from '@/stores/currentRemote'
import SdSidebar from './SdSidebar.vue'
import RemoteSelect from './RemoteSelect.vue'

const route = useRoute()
const remoteStore = useCurrentRemote()

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
</script>

<template>
  <RemoteSelect v-if="remoteStore.initialized && !remoteStore.selected" />
  <div v-show="remoteStore.selected" class="flex min-h-screen">
    <SdSidebar />
    <div class="flex-1 flex flex-col" style="background-color: var(--content-bg);">
      <header
        class="flex items-center px-6 bg-white border-b border-gray-200"
        style="height: var(--header-height);"
      >
        <el-breadcrumb separator="/">
          <el-breadcrumb-item :to="{ path: '/' }">Home</el-breadcrumb-item>
          <el-breadcrumb-item v-if="breadcrumb">{{ breadcrumb }}</el-breadcrumb-item>
        </el-breadcrumb>
        <div class="ml-auto flex items-center gap-3">
          <el-tag type="info" size="small" effect="plain">v0.1.0</el-tag>
        </div>
      </header>
      <main class="flex-1 p-6 overflow-auto">
        <slot />
      </main>
    </div>
  </div>
</template>
