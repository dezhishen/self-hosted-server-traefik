import { test, expect } from '@playwright/test'

test.describe('Remote Select Modal', () => {
  test.beforeEach(async ({ page }) => {
    // Clear any existing remote selection to trigger the modal
    await page.evaluate(() => localStorage.removeItem('selfhosted_remote'))
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  test('remote select modal shows when no endpoint selected', async ({ page }) => {
    // The modal should appear on first visit when no remote is selected
    const modal = page.locator('.fixed.inset-0.z-50')
    await expect(modal).toBeVisible()

    // Modal has title and connection icon
    await expect(modal.locator('h2')).toContainText('Remote Selection')
    await expect(modal.locator('.el-icon svg')).toBeVisible()
  })

  test('remote select modal has endpoint options', async ({ page }) => {
    const modal = page.locator('.fixed.inset-0.z-50')

    // Should have a select dropdown with endpoint options
    const select = modal.locator('.el-select')
    await expect(select).toBeVisible()

    // Should have options for endpoints
    const options = modal.locator('.el-select-dropdown .el-option')
    await expect(options.first()).toBeVisible()
  })

  test('remote select modal can select an endpoint', async ({ page }) => {
    const modal = page.locator('.fixed.inset-0.z-50')

    // Select an endpoint from the dropdown
    const select = modal.locator('.el-select')
    await select.click()

    // Wait for options to appear
    const options = page.locator('.el-select-dropdown')
    await options.waitFor({ state: 'visible', timeout: 5000 })

    // Click the first available option
    const firstOption = options.locator('.el-option').first()
    await firstOption.click()

    // Confirm button should become enabled
    const confirmBtn = modal.getByRole('button', { name: /confirm/i })
    await expect(confirmBtn).toBeEnabled()

    // Click confirm
    await confirmBtn.click()
    await page.waitForLoadState('networkidle')

    // Modal should close after selection
    await expect(modal).not.toBeVisible()

    // Should be redirected to dashboard (or home page)
    await expect(page).toHaveURL(/\/$/)
  })
})
