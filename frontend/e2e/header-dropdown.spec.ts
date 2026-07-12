import { test, expect } from '@playwright/test'

test.describe('Header - User Dropdown', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  test('user avatar button is visible in header', async ({ page }) => {
    const userBtn = page.locator('header .el-dropdown').first()
    await expect(userBtn).toBeVisible()
  })

  test('user dropdown shows all menu items', async ({ page }) => {
    // Open user dropdown
    const userDropdown = page.locator('header .el-dropdown').first()
    await userDropdown.click()
    await page.waitForTimeout(300)

    // All dropdown items should be visible
    await expect(page.getByRole('menuitem', { name: /migration/i })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: /settings/i })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: /subscriptions/i })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: /logout/i })).toBeVisible()
  })

  test('user dropdown settings link navigates to settings page', async ({ page }) => {
    // Open dropdown
    await page.locator('header .el-dropdown').first().click()
    await page.waitForTimeout(300)

    // Click Settings
    await page.getByRole('menuitem', { name: /settings/i }).click()
    await page.waitForLoadState('networkidle')

    await expect(page).toHaveURL(/\/settings/)
  })

  test('user dropdown subscriptions link navigates to subscriptions page', async ({ page }) => {
    await page.locator('header .el-dropdown').first().click()
    await page.waitForTimeout(300)

    await page.getByRole('menuitem', { name: /subscriptions/i }).click()
    await page.waitForLoadState('networkidle')

    await expect(page).toHaveURL(/\/subscriptions/)
  })

  test('user dropdown migration link navigates to migration page', async ({ page }) => {
    await page.locator('header .el-dropdown').first().click()
    await page.waitForTimeout(300)

    await page.getByRole('menuitem', { name: /migration/i }).click()
    await page.waitForLoadState('networkidle')

    await expect(page).toHaveURL(/\/migrate/)
  })
})
