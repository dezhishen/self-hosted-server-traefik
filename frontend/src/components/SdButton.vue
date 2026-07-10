<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{
  variant?: 'primary' | 'success' | 'warning' | 'danger' | 'info'
  size?: 'large' | 'default' | 'small'
  loading?: boolean
  disabled?: boolean
  icon?: string
  circle?: boolean
  text?: boolean
}>(), {
  variant: 'primary',
  size: 'default',
  loading: false,
  disabled: false,
  circle: false,
  text: false
})

const typeMap: Record<string, string> = {
  primary: 'primary',
  success: 'success',
  warning: 'warning',
  danger: 'danger',
  info: 'info'
}

const type = computed(() => typeMap[props.variant])
</script>

<template>
  <el-button
    :type="type"
    :size="size"
    :loading="loading"
    :disabled="disabled"
    :icon="icon"
    :circle="circle"
    :text="text"
  >
    <slot />
  </el-button>
</template>
