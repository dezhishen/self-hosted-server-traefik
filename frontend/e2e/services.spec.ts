import { test, expect } from '@playwright/test'

test.describe('Services', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/services')
    await page.waitForLoadState('networkidle')
  })

  test('page title and install button are visible', async ({ page }) => {
    await expect(page.locator('h2')).toContainText('Services')
    await expect(page.getByRole('button', { name: /Install/i })).toBeVisible()
  })

  test('search input is present and functional', async ({ page }) => {
    const search = page.locator('input[placeholder*="Search" i]')
    await expect(search).toBeVisible()
    await search.fill('traefik')
    await search.press('Enter')
    await page.waitForLoadState('networkidle')
  })

  test('refresh button triggers reload', async ({ page }) => {
    const refreshBtn = page.getByRole('button', { name: /Refresh/i })
    await expect(refreshBtn).toBeVisible()
    await refreshBtn.click()
    await page.waitForLoadState('networkidle')
  })

  test('service list table renders with columns', async ({ page }) => {
    const table = page.locator('.el-table')
    await expect(table).toBeVisible()

    await expect(page.getByText('Name').first()).toBeVisible()
    await expect(page.getByText('Description').first()).toBeVisible()
    await expect(page.getByText('Category').first()).toBeVisible()
    await expect(page.getByText('Status').first()).toBeVisible()
    await expect(page.getByText('Actions').first()).toBeVisible()
  })
})
