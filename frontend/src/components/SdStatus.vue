<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{
  status: string
  label?: string
}>(), {})

const colorMap: Record<string, string> = {
  running: '#67C23A',
  started: '#67C23A',
  healthy: '#67C23A',
  stopped: '#F56C6C',
  exited: '#F56C6C',
  error: '#F56C6C',
  restarting: '#E6A23C',
  paused: '#E6A23C',
  unknown: '#909399'
}

const color = computed(() => colorMap[props.status.toLowerCase()] || colorMap.unknown)
const displayLabel = computed(() => props.label || props.status)
</script>

<template>
  <span class="inline-flex items-center gap-1.5">
    <span
      class="inline-block w-2 h-2 rounded-full"
      :style="{ backgroundColor: color }"
    />
    <span class="text-sm">{{ displayLabel }}</span>
  </span>
</template>
