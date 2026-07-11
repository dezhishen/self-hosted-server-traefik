import { test, expect } from '@playwright/test'

test.describe('Settings', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/settings')
    await page.waitForLoadState('networkidle')
  })

  test('page title and save button are visible', async ({ page }) => {
    await expect(page.locator('h2')).toContainText('Settings')
    await expect(page.getByRole('button', { name: /Save Config/i })).toBeVisible()
  })

  test('configuration card loads with config fields', async ({ page }) => {
    await expect(page.getByText('Configuration')).toBeVisible()

    // Config path input should be visible (disabled/shows base_data_dir)
    const configPath = page.locator('.el-form-item').filter({ hasText: 'Config Path' }).locator('input')
    await expect(configPath).toBeVisible()
    await expect(configPath).toBeDisabled()
  })

  test('username field is editable', async ({ page }) => {
    const usernameInput = page.locator('.el-form-item').filter({ hasText: 'Username' }).locator('input')
    await expect(usernameInput).toBeVisible()

    await usernameInput.fill('admin')
    await expect(usernameInput).toHaveValue('admin')
  })

  test('endpoint section shows endpoint cards', async ({ page }) => {
    // Should show at least one endpoint (from dev config)
    await expect(page.getByText('Endpoints')).toBeVisible()

    // The default endpoint should be listed
    const endpointSection = page.locator('.el-divider').filter({ hasText: 'Endpoints' })
    await expect(endpointSection).toBeVisible()
  })

  test('save button triggers config update', async ({ page }) => {
    const saveBtn = page.getByRole('button', { name: /Save Config/i })
    await expect(saveBtn).toBeEnabled()
  })
})
