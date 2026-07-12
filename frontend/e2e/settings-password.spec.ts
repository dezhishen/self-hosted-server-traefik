import { test, expect } from '@playwright/test'

test.describe('Settings - Password Form', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/settings')
    await page.waitForLoadState('networkidle')
  })

  test('password fields are visible in settings', async ({ page }) => {
    // Should see password-related form items
    await expect(page.getByText('Username')).toBeVisible()

    // There should be password fields (current, new, confirm)
    await expect(page.getByText('Current Password')).toBeVisible()
    await expect(page.getByText('New Password')).toBeVisible()
    await expect(page.getByText('Confirm New Password')).toBeVisible()
  })

  test('password form has required fields', async ({ page }) => {
    // Current password input
    const currentPasswordInput = page.locator('.el-form-item').filter({ hasText: 'Current Password' }).locator('input[type="password"]')
    await expect(currentPasswordInput).toBeVisible()

    // New password input
    const newPasswordInput = page.locator('.el-form-item').filter({ hasText: 'New Password' }).locator('input[type="password"]')
    await expect(newPasswordInput).toBeVisible()

    // Confirm password input
    const confirmPasswordInput = page.locator('.el-form-item').filter({ hasText: 'Confirm New Password' }).locator('input[type="password"]')
    await expect(confirmPasswordInput).toBeVisible()
  })

  test('password form validation shows error on empty required fields', async ({ page }) => {
    // Try to save with empty password fields
    const saveBtn = page.getByRole('button', { name: /save config/i })
    await saveBtn.click()
    await page.waitForTimeout(500)

    // Should see validation error for required password fields
    const errorVisible = await page.locator('.el-message, .el-alert, .el-form-item--error').isVisible().catch(() => false)
    expect(errorVisible).toBe(true)
  })

  test('password form can be filled', async ({ page }) => {
    // Fill password fields
    const currentPasswordInput = page.locator('.el-form-item').filter({ hasText: 'Current Password' }).locator('input[type="password"]')
    const newPasswordInput = page.locator('.el-form-item').filter({ hasText: 'New Password' }).locator('input[type="password"]')
    const confirmPasswordInput = page.locator('.el-form-item').filter({ hasText: 'Confirm New Password' }).locator('input[type="password"]')

    await currentPasswordInput.fill('admin')
    await newPasswordInput.fill('newPassword123')
    await confirmPasswordInput.fill('newPassword123')

    // Verify values
    await expect(currentPasswordInput).toHaveValue('admin')
    await expect(newPasswordInput).toHaveValue('newPassword123')
    await expect(confirmPasswordInput).toHaveValue('newPassword123')
  })

  test('password form shows mismatch error when new and confirm differ', async ({ page }) => {
    // Fill passwords with mismatch
    await page.locator('.el-form-item').filter({ hasText: 'Current Password' }).locator('input[type="password"]').fill('admin')
    await page.locator('.el-form-item').filter({ hasText: 'New Password' }).locator('input[type="password"]').fill('newPassword123')
    await page.locator('.el-form-item').filter({ hasText: 'Confirm New Password' }).locator('input[type="password"]').fill('differentPassword')

    // Try to save
    const saveBtn = page.getByRole('button', { name: /save config/i })
    await saveBtn.click()
    await page.waitForTimeout(500)

    // Should show validation error for password mismatch
    const errorVisible = await page.locator('.el-message, .el-alert, .el-form-item--error').isVisible().catch(() => false)
    expect(errorVisible).toBe(true)
  })
})
