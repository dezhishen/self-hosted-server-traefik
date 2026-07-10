import { test, expect } from '@playwright/test'

test.describe('Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
  })

  test('should load the page', async ({ page }) => {
    await expect(page).toHaveTitle(/Selfhosted Dashboard/)
  })

  test('should show sidebar navigation', async ({ page }) => {
    await expect(page.locator('.el-menu')).toBeVisible()
  })

  test('should navigate to services page', async ({ page }) => {
    await page.getByText('Services').click()
    await expect(page).toHaveURL(/\/services/)
  })

  test('should navigate to subscriptions page', async ({ page }) => {
    await page.getByText('Subscriptions').click()
    await expect(page).toHaveURL(/\/subscriptions/)
  })

  test('should navigate to settings page', async ({ page }) => {
    await page.getByText('Settings').click()
    await expect(page).toHaveURL(/\/settings/)
  })
})
