import { test, expect } from '@playwright/test'

test.describe('Service Detail', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/services/traefik')
    await page.waitForLoadState('networkidle')
  })

  test('page shows service name from URL', async ({ page }) => {
    await expect(page.locator('h2')).toContainText('traefik')
  })

  test('action buttons are present', async ({ page }) => {
    await expect(page.getByRole('button', { name: /restart/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /uninstall/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /back/i })).toBeVisible()
  })

  test('tabs are rendered', async ({ page }) => {
    await expect(page.getByText(/detail|info/i)).toBeVisible()
    await expect(page.getByText(/status/i)).toBeVisible()
    await expect(page.getByText(/logs/i)).toBeVisible()
  })

  test('info tab shows service description fields', async ({ page }) => {
    // Wait for loading to finish
    await page.waitForTimeout(1000)

    // The info tab should show at minimum the field labels (even if empty)
    await expect(page.getByText('Name').first()).toBeVisible()
    await expect(page.getByText('Image').first()).toBeVisible()
  })

  test('logs tab can be switched to', async ({ page }) => {
    await page.getByText(/logs/i).click()
    await page.waitForTimeout(500)

    // Logs tab shows a refresh button
    await expect(page.getByRole('button', { name: /refresh/i }).first()).toBeVisible()
  })

  test('status tab can be switched to', async ({ page }) => {
    await page.getByText(/status/i).click()
    await page.waitForTimeout(500)
  })

  test('back button navigates to service list', async ({ page }) => {
    await page.getByRole('button', { name: /back/i }).click()
    await expect(page).toHaveURL(/\/services\/?$/)
  })

  test('uninstall button shows confirmation dialog', async ({ page }) => {
    await page.getByRole('button', { name: /uninstall/i }).click()
    // ElMessageBox confirm dialog should appear
    await page.waitForTimeout(500)
    const confirmDialog = page.locator('.el-message-box')
    await expect(confirmDialog).toBeVisible()
    // Close dialog (cancel)
    const cancelBtn = confirmDialog.getByRole('button', { name: /cancel|close/i })
    await cancelBtn.click()
    await expect(confirmDialog).not.toBeVisible()
  })
})
