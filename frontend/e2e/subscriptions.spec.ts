import { test, expect } from '@playwright/test'

test.describe('Subscriptions', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/subscriptions')
    await page.waitForLoadState('networkidle')
  })

  test('page title and add button are visible', async ({ page }) => {
    await expect(page.locator('h2')).toContainText('Subscriptions')
    await expect(page.getByRole('button', { name: /Add Subscription/i })).toBeVisible()
  })

  test('subscription table renders with columns', async ({ page }) => {
    const table = page.locator('.el-table')
    await expect(table).toBeVisible()

    await expect(page.getByText('Name').first()).toBeVisible()
    await expect(page.getByText('URL').first()).toBeVisible()
    await expect(page.getByText('Enabled').first()).toBeVisible()
    await expect(page.getByText('Auto Update').first()).toBeVisible()
    await expect(page.getByText('Actions').first()).toBeVisible()
  })

  test('add subscription dialog opens and closes', async ({ page }) => {
    await page.getByRole('button', { name: /Add Subscription/i }).click()
    await expect(page.locator('.el-dialog__title')).toHaveText('Add Subscription')
    await expect(page.locator('.el-dialog')).toBeVisible()

    // Dialog has name and url inputs
    await expect(page.locator('.el-form-item').filter({ hasText: 'Name' }).locator('input')).toBeVisible()
    await expect(page.locator('.el-form-item').filter({ hasText: 'URL' }).locator('input')).toBeVisible()

    // Close dialog
    await page.locator('.el-dialog .el-dialog__close').click()
    await expect(page.locator('.el-dialog')).not.toBeVisible()
  })

  test('can fill and cancel add subscription form', async ({ page }) => {
    await page.getByRole('button', { name: /Add Subscription/i }).click()
    await expect(page.locator('.el-dialog')).toBeVisible()

    const nameInput = page.locator('.el-form-item').filter({ hasText: 'Name' }).locator('input')
    const urlInput = page.locator('.el-form-item').filter({ hasText: 'URL' }).locator('input')

    await nameInput.fill('test-repo')
    await urlInput.fill('https://github.com/user/repo')

    await expect(nameInput).toHaveValue('test-repo')
    await expect(urlInput).toHaveValue('https://github.com/user/repo')

    // Cancel
    await page.locator('.el-dialog .el-dialog__close').click()
    await expect(page.locator('.el-dialog')).not.toBeVisible()
  })
})
