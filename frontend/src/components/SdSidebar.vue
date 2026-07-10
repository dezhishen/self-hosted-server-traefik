<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useCurrentRemote } from '@/stores/currentRemote'
import {
  Monitor,
  Grid,
  Link,
  Tickets,
  Fold,
  Expand
} from '@element-plus/icons-vue'

defineProps<{
  mobileOpen: boolean
}>()

const emit = defineEmits<{
  close: []
}>()

const route = useRoute()
const router = useRouter()
const remoteStore = useCurrentRemote()

const isCollapsed = ref(false)

const menuItems = [
  { path: '/', icon: Monitor, label: 'Dashboard' },
  { path: '/services', icon: Grid, label: 'Services' },
  { path: '/subscriptions', icon: Tickets, label: 'Subscriptions' },
  { path: '/settings', icon: Link, label: 'Settings' }
]

const activeIndex = computed(() => route.path)

function handleSelect(path: string) {
  emit('close')
  router.push(path)
}

function toggleCollapse() {
  isCollapsed.value = !isCollapsed.value
}

function onRemoteChange(name: string) {
  remoteStore.select(name)
}
</script>

<template>
  <Teleport to="body">
    <transition name="sidebar-backdrop">
      <div
        v-if="mobileOpen"
        class="sidebar-overlay md:hidden"
        @click="emit('close')"
      />
    </transition>
  </Teleport>

  <aside
    :class="[
      isCollapsed ? 'w-[64px]' : 'w-[220px]',
      mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0',
    ]"
    class="sidebar-aside"
    style="background-color: var(--sidebar-bg); min-height: 100vh; transition: width 0.3s, transform 0.3s;"
  >
    <div class="sidebar-logo">
      <img src="@/assets/logo.svg" alt="Logo" />
      <span v-show="!isCollapsed">SelfHosted</span>
    </div>

    <div v-if="!isCollapsed && remoteStore.remotes.length > 0" class="px-3 mb-2">
      <el-select
        :model-value="remoteStore.current"
        :placeholder="remoteStore.loading ? 'Loading...' : 'Select Remote'"
        class="w-full" size="small" @change="onRemoteChange"
      >
        <el-option v-for="r in remoteStore.remotes" :key="r.name" :label="r.name" :value="r.name">
          <span>{{ r.name }}</span>
          <span v-if="r.default" class="ml-1 text-yellow-500 text-xs">(default)</span>
        </el-option>
      </el-select>
    </div>

    <el-menu
      :default-active="activeIndex"
      :collapse="isCollapsed"
      :collapse-transition="false"
      background-color="#1d1e1f"
      text-color="#bfcbd9"
      active-text-color="#409eff"
      style="border-right: none; flex: 1;"
      @select="handleSelect"
    >
      <el-menu-item v-for="item in menuItems" :key="item.path" :index="item.path">
        <el-icon><component :is="item.icon" /></el-icon>
        <template #title>{{ item.label }}</template>
      </el-menu-item>
    </el-menu>

    <div class="p-3 border-t border-white/10 hidden md:flex justify-center">
      <el-button
        :icon="isCollapsed ? Expand : Fold"
        size="small" text bg
        style="color: #bfcbd9;" @click="toggleCollapse"
      >
        <template v-if="!isCollapsed">Collapse</template>
      </el-button>
    </div>
  </aside>
</template>
