import { test, expect } from '@playwright/test'

test.describe('Services', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/services')
  })

  test('should show service list page', async ({ page }) => {
    await expect(page.locator('text=Services')).toBeVisible()
  })

  test('should show search input', async ({ page }) => {
    await expect(page.locator('input[placeholder*="search" i]')).toBeVisible()
  })

  test('should show install service button', async ({ page }) => {
    await expect(page.getByRole('button', { name: /install/i })).toBeVisible()
  })
})
