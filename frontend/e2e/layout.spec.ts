import { test, expect } from '@playwright/test'

test.describe('Layout & Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  test('sidebar shows navigation items', async ({ page }) => {
    await expect(page.getByRole('menuitem', { name: 'Dashboard' })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: 'Services' })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: 'Subscriptions' })).toBeVisible()
    await expect(page.getByRole('menuitem', { name: 'Settings' })).toBeVisible()
  })

  test('sidebar logo and title are visible', async ({ page }) => {
    await expect(page.locator('.sidebar-logo')).toBeVisible()
    await expect(page.locator('.sidebar-logo span')).toContainText('SelfHosted')
  })

  test('sidebar navigation navigates to each route', async ({ page }) => {
    const links = [
      { label: 'Services', url: /\/services/ },
      { label: 'Subscriptions', url: /\/subscriptions/ },
      { label: 'Settings', url: /\/settings/ },
    ]

    for (const { label, url } of links) {
      await page.getByText(label).first().click()
      await page.waitForLoadState('networkidle')
      await expect(page).toHaveURL(url)
    }

    // Navigate back to Dashboard
    await page.getByText('Dashboard').first().click()
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveURL(/\/$/)
  })

  test('header shows breadcrumb for each page', async ({ page }) => {
    await page.getByText('Services').first().click()
    await page.waitForLoadState('networkidle')
    await expect(page.getByText('Services').first()).toBeVisible()

    await page.getByText('Settings').first().click()
    await page.waitForLoadState('networkidle')
    await expect(page.getByText('Settings').first()).toBeVisible()
  })

  test('sidebar endpoint selector is visible', async ({ page }) => {
    const select = page.locator('.el-select').first()
    await expect(select).toBeVisible()
  })
})
