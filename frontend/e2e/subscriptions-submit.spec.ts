import { test, expect } from '@playwright/test'

test.describe('Subscriptions - Form Submission', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/subscriptions')
    await page.waitForLoadState('networkidle')
  })

  test('add subscription dialog form can be filled and submitted', async ({ page }) => {
    // Open add dialog
    await page.getByRole('button', { name: /add subscription/i }).click()
    await expect(page.locator('.el-dialog')).toBeVisible()

    // Fill form fields
    await page.locator('.el-form-item').filter({ hasText: 'Name' }).locator('input').fill('test-repo')
    await page.locator('.el-form-item').filter({ hasText: 'URL' }).locator('input').fill('https://github.com/test/repo')

    // Verify values
    await expect(page.locator('.el-form-item').filter({ hasText: 'Name' }).locator('input')).toHaveValue('test-repo')
    await expect(page.locator('.el-form-item').filter({ hasText: 'URL' }).locator('input')).toHaveValue('https://github.com/test/repo')

    // Submit form
    await page.locator('.el-dialog').getByRole('button', { name: /add|save/i }).click()
    await page.waitForLoadState('networkidle')

    // Should see success message or dialog closes
    // The dialog should close on successful submit
    await expect(page.locator('.el-dialog')).not.toBeVisible()
  })

  test('add subscription requires name and URL', async ({ page }) => {
    // Open add dialog
    await page.getByRole('button', { name: /add subscription/i }).click()
    await expect(page.locator('.el-dialog')).toBeVisible()

    // Try to submit with empty fields
    await page.locator('.el-dialog').getByRole('button', { name: /add|save/i }).click()
    await page.waitForTimeout(500)

    // Should see validation error (ElMessage) or fields remain highlighted
    // ElMessage usually appears for required field validation
    const errorMessage = page.locator('.el-message, .el-alert, .el-form-item--error')
    // Either error appears or dialog stays open (validation failed)
    const errorVisible = await errorMessage.isVisible().catch(() => false)
    const dialogStillOpen = await page.locator('.el-dialog').isVisible()
    expect(errorVisible || dialogStillOpen).toBe(true)
  })

  test('add subscription with invalid URL shows error', async ({ page }) => {
    // Open add dialog
    await page.getByRole('button', { name: /add subscription/i }).click()
    await expect(page.locator('.el-dialog')).toBeVisible()

    // Fill with invalid URL
    await page.locator('.el-form-item').filter({ hasText: 'Name' }).locator('input').fill('test-repo')
    await page.locator('.el-form-item').filter({ hasText: 'URL' }).locator('input').fill('not-a-valid-url')

    // Try to submit
    await page.locator('.el-dialog').getByRole('button', { name: /add|save/i }).click()
    await page.waitForTimeout(500)

    // Should show validation error
    const errorVisible = await page.locator('.el-message, .el-alert, .el-form-item--error').isVisible().catch(() => false)
    expect(errorVisible).toBe(true)
  })
})
