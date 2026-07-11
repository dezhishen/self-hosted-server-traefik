<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useCurrentRemote } from '@/stores/currentRemote'
import { useThemeStore } from '@/stores/theme'
import {
  Monitor,
  Grid,
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
const themeStore = useThemeStore()
const { t } = useI18n()

const isCollapsed = ref(false)

const menuItems = [
  { path: '/', icon: Monitor, label: 'nav.dashboard' },
  { path: '/services', icon: Grid, label: 'nav.services' }
]

const activeIndex = computed(() => route.path)

function handleSelect(path: string) {
  emit('close')
  router.push(path)
}

function toggleCollapse() {
  isCollapsed.value = !isCollapsed.value
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
    <div class="sidebar-logo" :class="{ 'justify-center': isCollapsed }">
      <img src="@/assets/logo.svg" alt="Logo" />
      <span v-show="!isCollapsed" class="flex-1 ml-2">SelfHosted</span>
      <!-- Collapse toggle, visible on desktop -->
      <el-button
        v-show="!isCollapsed"
        :icon="Fold"
        size="small" text
        style="color: var(--sidebar-text);"
        class="hidden md:inline-flex"
        @click="toggleCollapse"
      />
      <el-button
        v-show="isCollapsed"
        :icon="Expand"
        size="small" text
        style="color: var(--sidebar-text);"
        class="hidden md:inline-flex"
        @click="toggleCollapse"
      />
    </div>

    <!-- Current endpoint indicator (read-only) -->
    <div
      v-show="!isCollapsed && remoteStore.current"
      class="px-3 mb-2 text-xs truncate"
      style="color: var(--sidebar-text); opacity: 0.7;"
    >
      {{ remoteStore.current }}
    </div>

    <el-menu
      :default-active="activeIndex"
      :collapse="isCollapsed"
      :collapse-transition="false"
      :background-color="themeStore.isDark ? '#0d0d1a' : '#1d1e1f'"
      text-color="var(--sidebar-text)"
      active-text-color="var(--sidebar-active-bg)"
      style="border-right: none; flex: 1;"
      @select="handleSelect"
    >
      <el-menu-item v-for="item in menuItems" :key="item.path" :index="item.path">
        <el-icon><component :is="item.icon" /></el-icon>
        <template #title>{{ t(item.label) }}</template>
      </el-menu-item>
    </el-menu>
  </aside>
</template>
