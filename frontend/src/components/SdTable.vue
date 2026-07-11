<script setup lang="ts">
interface Column {
  prop: string
  label: string
  width?: string | number
  align?: 'left' | 'center' | 'right'
  formatter?: (row: any, column: any, cellValue: any, index: number) => any
}

withDefaults(defineProps<{
  data: any[]
  columns: Column[]
  loading?: boolean
  size?: 'large' | 'default' | 'small'
  pagination?: {
    current: number
    pageSize: number
    total: number
  }
  stripe?: boolean
  border?: boolean
  maxHeight?: string | number
}>(), {
  loading: false,
  size: 'small',
  stripe: true,
  border: true
})

const emit = defineEmits<{
  (e: 'page-change', page: number): void
  (e: 'size-change', size: number): void
}>()
</script>

<template>
  <div>
    <el-table
      :data="data"
      :stripe="stripe"
      :border="border"
      :loading="loading"
      :size="size"
      :max-height="maxHeight"
      style="width: 100%"
      empty-text="No data available"
    >
      <el-table-column
        v-for="col in columns"
        :key="col.prop"
        :prop="col.prop"
        :label="col.label"
        :width="col.width"
        :align="col.align || 'left'"
        :formatter="col.formatter"
      />
      <template v-if="$slots.default">
        <slot />
      </template>
    </el-table>
    <div v-if="pagination" class="flex justify-end mt-4">
      <el-pagination
        v-model:current-page="pagination.current"
        v-model:page-size="pagination.pageSize"
        :total="pagination.total"
        :page-sizes="[10, 20, 50, 100]"
        layout="total, sizes, prev, pager, next, jumper"
        background
        @current-change="emit('page-change', $event)"
        @size-change="emit('size-change', $event)"
      />
    </div>
  </div>
</template>
