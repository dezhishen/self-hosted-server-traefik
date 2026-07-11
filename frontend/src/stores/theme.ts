import { defineStore } from 'pinia'
import { useDark, useToggle } from '@vueuse/core'

export const useThemeStore = defineStore('theme', () => {
  const isDark = useDark({
    storageKey: 'selfhosted_dark'
  })
  const toggleDark = useToggle(isDark)

  return { isDark, toggleDark }
})
