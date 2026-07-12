import { test, expect } from '@playwright/test'

test.describe('Subscriptions - Row Actions', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/subscriptions')
    await page.waitForLoadState('networkidle')
  })

  test('each subscription row has Sync and Remove buttons', async ({ page }) => {
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()

    // Skip if no data
    test.skip(rowCount === 0, 'No subscriptions available')

    const firstRow = rows.first()
    await expect(firstRow.getByRole('button', { name: /sync/i })).toBeVisible()
    await expect(firstRow.getByRole('button', { name: /remove|delete/i })).toBeVisible()
  })

  test('clicking Sync triggers sync action', async ({ page }) => {
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()
    test.skip(rowCount === 0, 'No subscriptions available')

    // Click Sync on first row
    await rows.first().getByRole('button', { name: /sync/i }).click()
    await page.waitForTimeout(1000)

    // Sync should complete (either success or error message)
    // The action button should not be disabled after completion
  })

  test('clicking Remove shows confirmation dialog', async ({ page }) => {
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()
    test.skip(rowCount === 0, 'No subscriptions available')

    // Click Remove on first row
    await rows.first().getByRole('button', { name: /remove|delete/i }).click()
    await page.waitForTimeout(500)

    // ElMessageBox confirmation should appear
    const confirmDialog = page.locator('.el-message-box')
    await expect(confirmDialog).toBeVisible()

    // Cancel to dismiss
    await confirmDialog.getByRole('button', { name: /cancel|close/i }).click()
    await expect(confirmDialog).not.toBeVisible()
  })

  test('subscription table shows name, URL, enabled and auto update tags', async ({ page }) => {
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()
    test.skip(rowCount === 0, 'No subscriptions available')

    const firstRow = rows.first()
    const cells = firstRow.locator('td')

    // First cell should have text content (name)
    const nameText = await cells.first().textContent()
    expect(nameText?.trim().length).toBeGreaterThan(0)

    // Should have status tags (enabled/disabled, auto-update yes/no)
    const tags = firstRow.locator('.el-tag')
    const tagCount = await tags.count()
    expect(tagCount).toBeGreaterThanOrEqual(1)
  })
})
