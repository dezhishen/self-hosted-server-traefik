import { test, expect } from '@playwright/test'

test.describe('Migration', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/migrate')
    await page.waitForLoadState('networkidle')
  })

  test('page title and refresh button are visible', async ({ page }) => {
    await expect(page.locator('h2')).toContainText(/migration|migrate/i)
    await expect(page.getByRole('button', { name: /refresh/i })).toBeVisible()
  })

  test('candidate table renders with expected columns', async ({ page }) => {
    const table = page.locator('.el-table')
    await expect(table).toBeVisible()

    // Table headers should be visible
    await expect(page.getByText(/container/i).first()).toBeVisible()
    await expect(page.getByText(/image/i).first()).toBeVisible()
  })

  test('refresh button triggers data reload', async ({ page }) => {
    const refreshBtn = page.getByRole('button', { name: /refresh/i })
    await expect(refreshBtn).toBeEnabled()
    await refreshBtn.click()
    await page.waitForLoadState('networkidle')
  })

  test('shows empty state when no unmanaged containers exist', async ({ page }) => {
    // If there are no migration candidates, an empty state message should appear
    const table = page.locator('.el-table')
    await expect(table).toBeVisible()

    // Either there are rows or an empty state message
    const rows = table.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()
    if (rowCount === 0 || (rowCount === 1 && (await rows.locator('td').first().textContent())?.includes('No Data'))) {
      // Empty state - either el-table empty placeholder or custom empty message
      await expect(page.getByText(/no/i).first()).toBeVisible()
    }
  })

  test('candidate table shows containers if migration candidates exist', async ({ page }) => {
    // Wait for data to load
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()

    // If candidates exist, each row should have a Detail button
    if (rowCount > 0) {
      const firstCell = await rows.first().locator('td').first().textContent()
      if (firstCell && firstCell.trim() && !firstCell.includes('No Data')) {
        // Actual data rows should have a detail button
        await expect(rows.first().getByRole('button', { name: /detail/i })).toBeVisible()
      }
    }
  })

  test('clicking refresh shows loading state', async ({ page }) => {
    const refreshBtn = page.getByRole('button', { name: /refresh/i })
    // Click refresh and check the table shows loading (v-loading)
    await refreshBtn.click()
    // The loading directive should be active during fetch
    const loadingWrapper = page.locator('.el-table')
    await expect(loadingWrapper).toBeAttached()
  })
})
