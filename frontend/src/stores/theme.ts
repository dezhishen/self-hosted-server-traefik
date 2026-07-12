import { defineStore } from 'pinia'
import { computed, watch } from 'vue'
import { usePreferredDark, useStorage } from '@vueuse/core'

export type ThemeMode = 'system' | 'light' | 'dark'

export const useThemeStore = defineStore('theme', () => {
  const preferredDark = usePreferredDark()
  const mode = useStorage<ThemeMode>('selfhosted_theme_mode', 'system')

  const isDark = computed(() => {
    if (mode.value === 'system') return preferredDark.value
    return mode.value === 'dark'
  })

  // Sync dark class on <html>
  watch(isDark, (val) => {
    document.documentElement.classList.toggle('dark', val)
  }, { immediate: true })

  function cycleMode() {
    // system → dark → light → system
    if (mode.value === 'system') mode.value = 'dark'
    else if (mode.value === 'dark') mode.value = 'light'
    else mode.value = 'system'
  }

  return { isDark, mode, cycleMode }
})
