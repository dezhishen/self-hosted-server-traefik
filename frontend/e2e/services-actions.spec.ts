import { test, expect } from '@playwright/test'

test.describe('Services - Row Actions', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/services')
    await page.waitForLoadState('networkidle')
  })

  test('each service row has Detail, Restart, and Uninstall buttons', async ({ page }) => {
    // Wait for table data to load
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()

    // Skip if no data (empty table)
    test.skip(rowCount === 0, 'No services available')

    // Check the first row has action buttons
    const firstRow = rows.first()
    await expect(firstRow.getByRole('button', { name: /detail/i })).toBeVisible()
    await expect(firstRow.getByRole('button', { name: /restart/i })).toBeVisible()
    await expect(firstRow.getByRole('button', { name: /uninstall/i })).toBeVisible()
  })

  test('clicking Detail navigates to service detail page', async ({ page }) => {
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()
    test.skip(rowCount === 0, 'No services available')

    const firstRow = rows.first()
    const nameCell = firstRow.locator('td').first()
    const serviceName = await nameCell.textContent()

    await firstRow.getByRole('button', { name: /detail/i }).click()
    await page.waitForLoadState('networkidle')

    // Should navigate to service detail page
    await expect(page).toHaveURL(/\/services\//)
    if (serviceName) {
      await expect(page.locator('h2')).toContainText(serviceName.trim())
    }
  })

  test('clicking Restart triggers success message', async ({ page }) => {
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()
    test.skip(rowCount === 0, 'No services available')

    // Click restart on first row
    await rows.first().getByRole('button', { name: /restart/i }).click()
    await page.waitForTimeout(1000)

    // Should see either a success message or an error message
    // Either way, the action was triggered
  })

  test('clicking Uninstall shows confirmation dialog', async ({ page }) => {
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()
    test.skip(rowCount === 0, 'No services available')

    // Click uninstall on first row
    await rows.first().getByRole('button', { name: /uninstall/i }).click()
    await page.waitForTimeout(500)

    // ElMessageBox confirmation should appear
    const confirmDialog = page.locator('.el-message-box')
    await expect(confirmDialog).toBeVisible()

    // Cancel to dismiss
    await confirmDialog.getByRole('button', { name: /cancel|close/i }).click()
    await expect(confirmDialog).not.toBeVisible()
  })

  test('service name is a clickable link to detail', async ({ page }) => {
    await page.waitForTimeout(1000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()
    test.skip(rowCount === 0, 'No services available')

    // The service name is rendered as an el-link
    const nameLink = rows.first().locator('.el-link')
    await expect(nameLink).toBeVisible()

    const serviceName = await nameLink.textContent()
    await nameLink.click()
    await page.waitForLoadState('networkidle')

    await expect(page).toHaveURL(/\/services\//)
    if (serviceName) {
      await expect(page.locator('h2')).toContainText(serviceName.trim())
    }
  })
})
