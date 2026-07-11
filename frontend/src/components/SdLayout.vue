<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useCurrentRemote } from '@/stores/currentRemote'
import { useAuthStore } from '@/stores/auth'
import { useThemeStore } from '@/stores/theme'
import SdSidebar from './SdSidebar.vue'
import RemoteSelect from './RemoteSelect.vue'
import { Operation, Setting, Tickets, SwitchButton, User } from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const { t, locale } = useI18n()
const remoteStore = useCurrentRemote()
const authStore = useAuthStore()
const themeStore = useThemeStore()

const sidebarOpen = ref(false)

onMounted(() => {
  if (!remoteStore.initialized) {
    remoteStore.fetchRemotes()
  }
})

const isLoginPage = computed(() => route.name === 'Login')

const breadcrumbMap: Record<string, string> = {
  Dashboard: 'nav.dashboard',
  ServiceList: 'nav.services',
  ServiceDetail: 'services.detail',
  ParamList: 'services.params',
  SubscriptionList: 'nav.subscriptions',
  Settings: 'nav.settings',
  Migration: 'nav.migration'
}

const breadcrumb = computed(() => {
  const key = breadcrumbMap[route.name as string]
  return key ? t(key) : ''
})

function toggleSidebar() {
  sidebarOpen.value = !sidebarOpen.value
}

function closeSidebar() {
  sidebarOpen.value = false
}

function onRemoteChange(name: string) {
  remoteStore.select(name)
}

function toggleLanguage() {
  const next = locale.value === 'en' ? 'zh-CN' : 'en'
  locale.value = next
  localStorage.setItem('selfhosted_locale', next)
}

function handleUserCommand(command: string) {
  if (command === 'logout') {
    authStore.logout()
    router.push('/login')
  } else {
    router.push(command)
  }
}
</script>

<template>
  <!-- Login page: render without layout -->
  <template v-if="isLoginPage">
    <slot />
  </template>

  <!-- All other pages: show sidebar + header layout -->
  <template v-else>
    <RemoteSelect v-if="remoteStore.initialized && !remoteStore.selected" />
    <div v-show="remoteStore.selected" class="flex min-h-screen">
      <SdSidebar :mobile-open="sidebarOpen" @close="closeSidebar" />
      <div class="flex-1 flex flex-col min-w-0" style="background-color: var(--content-bg);">
        <header
          class="flex items-center px-4 md:px-6 border-b sticky top-0 z-30"
          style="height: var(--header-height); background-color: var(--bg-primary); border-color: var(--border-color);"
        >
          <el-button
            class="md:!hidden mr-3"
            :icon="Operation"
            size="small"
            text
            @click="toggleSidebar"
          />
          <el-breadcrumb separator="/" class="hidden md:flex">
            <el-breadcrumb-item :to="{ path: '/' }">{{ t('nav.dashboard') }}</el-breadcrumb-item>
            <el-breadcrumb-item v-if="breadcrumb">{{ breadcrumb }}</el-breadcrumb-item>
          </el-breadcrumb>
          <el-breadcrumb separator="/" class="md:hidden text-sm">
            <el-breadcrumb-item v-if="breadcrumb">{{ breadcrumb }}</el-breadcrumb-item>
          </el-breadcrumb>

          <!-- Right side controls -->
          <div class="ml-auto flex items-center gap-2">
            <!-- Endpoint selector -->
            <el-select
              v-if="remoteStore.remotes.length > 0"
              :model-value="remoteStore.current"
              size="small"
              class="w-32 hidden sm:inline-flex"
              @change="onRemoteChange"
            >
              <el-option
                v-for="r in remoteStore.remotes"
                :key="r.name"
                :label="r.name"
                :value="r.name"
              />
            </el-select>

            <!-- Dark mode toggle -->
            <el-button
              size="small"
              text
              @click="themeStore.toggleDark()"
            >
              {{ themeStore.isDark ? '☀️' : '🌙' }}
            </el-button>

            <!-- Language switcher -->
            <el-button
              size="small"
              text
              @click="toggleLanguage"
            >
              {{ locale === 'en' ? '中' : 'EN' }}
            </el-button>

            <!-- User dropdown (authenticated): Settings, Subscriptions, Logout -->
            <template v-if="authStore.authenticated">
              <el-dropdown trigger="click" @command="handleUserCommand">
                <el-button size="small" text>
                  <el-icon><User /></el-icon>
                  <span class="ml-1">{{ authStore.username }}</span>
                </el-button>
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item command="/migrate">
                      {{ t('nav.migration') }}
                    </el-dropdown-item>
                    <el-dropdown-item :icon="Setting" command="/settings">
                      {{ t('nav.settings') }}
                    </el-dropdown-item>
                    <el-dropdown-item :icon="Tickets" command="/subscriptions">
                      {{ t('nav.subscriptions') }}
                    </el-dropdown-item>
                    <el-dropdown-item divided :icon="SwitchButton" command="logout">
                      {{ t('nav.logout') }}
                    </el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </template>
            <el-button v-else size="small" text @click="router.push('/login')">
              {{ t('nav.login') }}
            </el-button>
          </div>
        </header>
        <main class="flex-1 p-4 md:p-6 overflow-auto">
          <slot />
        </main>
      </div>
    </div>
  </template>
</template>
