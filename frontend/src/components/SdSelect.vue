<script setup lang="ts">
interface Option {
  label: string
  value: string | number | boolean
  disabled?: boolean
}

withDefaults(defineProps<{
  modelValue: string | number | boolean
  options: Option[]
  label?: string
  placeholder?: string
  disabled?: boolean
}>(), {
  disabled: false,
  placeholder: 'Select'
})

const emit = defineEmits<{
  (e: 'update:modelValue', val: string | number | boolean): void
}>()
</script>

<template>
  <div class="mb-4">
    <label v-if="label" class="block text-sm font-medium text-gray-700 mb-1">{{ label }}</label>
    <el-select
      :model-value="modelValue"
      :placeholder="placeholder"
      :disabled="disabled"
      class="w-full"
      @update:model-value="emit('update:modelValue', $event)"
    >
      <el-option
        v-for="opt in options"
        :key="String(opt.value)"
        :label="opt.label"
        :value="opt.value"
        :disabled="opt.disabled"
      />
    </el-select>
  </div>
</template>
