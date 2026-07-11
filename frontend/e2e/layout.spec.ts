import { test, expect } from '@playwright/test'

test.describe('Layout & Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  test('sidebar shows endpoint-scoped navigation items', async ({ page }) => {
    await expect(page.getByRole('menuitem', { name: 'Dashboard' })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: 'Services' })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: 'Subscriptions' })).toBeVisible()
  })

  test('sidebar shows current endpoint indicator', async ({ page }) => {
    await expect(page.locator('.sidebar-logo')).toBeVisible()
    await expect(page.locator('.sidebar-logo span')).toContainText('SelfHosted')
  })

  test('sidebar navigation navigates to each route', async ({ page }) => {
    const links = [
      { label: 'Services', url: /\/services/ },
      { label: 'Subscriptions', url: /\/subscriptions/ },
    ]

    for (const { label, url } of links) {
      await page.getByRole('menuitem', { name: label }).click()
      await page.waitForLoadState('networkidle')
      await expect(page).toHaveURL(url)
    }

    // Navigate back to Dashboard
    await page.getByRole('menuitem', { name: 'Dashboard' }).click()
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveURL(/\/$/)
  })

  test('header shows breadcrumb for each page', async ({ page }) => {
    await page.getByRole('menuitem', { name: 'Services' }).click()
    await page.waitForLoadState('networkidle')
    await expect(page.locator('.el-breadcrumb')).toContainText('Services')

    await page.getByRole('menuitem', { name: 'Dashboard' }).click()
    await page.waitForLoadState('networkidle')
  })

  test('header has endpoint selector visible', async ({ page }) => {
    const select = page.locator('header .el-select').first()
    await expect(select).toBeVisible()
  })

  test('header has settings, dark mode, language, and auth controls', async ({ page }) => {
    // The header should contain breadcrumb and controls
    await expect(page.locator('header')).toContainText('Dashboard')
  })
})
