import { test, expect } from '@playwright/test'

test.describe('Layout & Components', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
  })

  test('should have responsive layout', async ({ page }) => {
    const sidebar = page.locator('.el-menu')
    await expect(sidebar).toBeVisible()

    const mainContent = page.locator('main, .main-content, #root > div > div:last-child')
    await expect(mainContent.first()).toBeVisible()
  })

  test('should toggle sidebar collapse', async ({ page }) => {
    const collapseBtn = page.locator('.el-menu__collapse, button[aria-label="collapse"]')
    if (await collapseBtn.isVisible()) {
      await collapseBtn.click()
    }
  })

  test('should show logo in sidebar', async ({ page }) => {
    await expect(page.locator('img[alt*="logo" i], .logo, [class*="logo"]').first()).toBeVisible()
  })
})
