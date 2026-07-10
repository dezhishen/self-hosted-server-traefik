<script setup lang="ts">
withDefaults(defineProps<{
  shadow?: 'always' | 'hover' | 'never'
  padding?: string
}>(), {
  shadow: 'hover',
  padding: '20px'
})
</script>

<template>
  <el-card :shadow="shadow" :body-style="{ padding }" class="mb-4">
    <template v-if="$slots.header" #header>
      <slot name="header" />
    </template>
    <slot />
    <template v-if="$slots.footer" #footer>
      <div class="border-t border-gray-100 pt-4 mt-4">
        <slot name="footer" />
      </div>
    </template>
  </el-card>
</template>
