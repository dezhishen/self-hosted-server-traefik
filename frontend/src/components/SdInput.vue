<script setup lang="ts">
withDefaults(defineProps<{
  modelValue: string
  label?: string
  type?: 'text' | 'password' | 'textarea'
  placeholder?: string
  error?: string
  disabled?: boolean
  rows?: number
  readonly?: boolean
}>(), {
  type: 'text',
  disabled: false,
  readonly: false,
  rows: 4
})

const emit = defineEmits<{
  (e: 'update:modelValue', val: string): void
}>()
</script>

<template>
  <div class="mb-4">
    <label v-if="label" class="block text-sm font-medium text-gray-700 mb-1">{{ label }}</label>
    <el-input
      :model-value="modelValue"
      :type="type"
      :placeholder="placeholder"
      :disabled="disabled"
      :rows="rows"
      :readonly="readonly"
      @update:model-value="emit('update:modelValue', $event)"
    />
    <p v-if="error" class="mt-1 text-sm text-red-500">{{ error }}</p>
  </div>
</template>
