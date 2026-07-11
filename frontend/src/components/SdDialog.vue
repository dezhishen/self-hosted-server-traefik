<script setup lang="ts">
withDefaults(defineProps<{
  title: string
  visible: boolean
  width?: string
  confirmText?: string
  cancelText?: string
  confirmLoading?: boolean
}>(), {
  width: 'min(600px, 92vw)',
  confirmText: 'Confirm',
  cancelText: 'Cancel',
  confirmLoading: false
})

const emit = defineEmits<{
  (e: 'update:visible', val: boolean): void
  (e: 'confirm'): void
  (e: 'cancel'): void
}>()

function handleClose() {
  emit('update:visible', false)
}

function handleConfirm() {
  emit('confirm')
}
</script>

<template>
  <el-dialog
    :model-value="visible"
    :title="title"
    :width="width"
    :close-on-click-modal="false"
    @update:model-value="emit('update:visible', $event as boolean)"
  >
    <slot />
    <template #footer>
      <div class="flex justify-end gap-2">
        <el-button @click="handleClose">{{ cancelText }}</el-button>
        <el-button type="primary" :loading="confirmLoading" @click="handleConfirm">
          {{ confirmText }}
        </el-button>
      </div>
    </template>
  </el-dialog>
</template>
