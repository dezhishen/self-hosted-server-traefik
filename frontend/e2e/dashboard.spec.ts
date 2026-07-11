import { test, expect } from '@playwright/test'

test.describe('Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  test('should show the page title', async ({ page }) => {
    await expect(page.locator('h2')).toContainText('Dashboard')
  })

  test('should show stat cards with labels', async ({ page }) => {
    await expect(page.getByText('Engine')).toBeVisible()
    await expect(page.getByText('Version')).toBeVisible()
    await expect(page.getByText('Running')).toBeVisible()
    await expect(page.getByText('Stopped')).toBeVisible()
  })

  test('should show runtime info section', async ({ page }) => {
    await expect(page.getByText('Runtime Info')).toBeVisible()
  })

  test('should show quick actions card with buttons', async ({ page }) => {
    await expect(page.getByText('Quick Actions')).toBeVisible()
    await expect(page.getByRole('button', { name: /Manage Services/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /Subscriptions/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /Settings/i })).toBeVisible()
  })

  test('should show container overview table', async ({ page }) => {
    await expect(page.getByText('Container Overview')).toBeVisible()
  })

  test('quick action buttons navigate correctly', async ({ page }) => {
    await page.getByRole('button', { name: /Manage Services/i }).click()
    await expect(page).toHaveURL(/\/services/)

    await page.goto('/')
    await page.waitForLoadState('networkidle')

    await page.getByRole('button', { name: /Subscriptions/i }).click()
    await expect(page).toHaveURL(/\/subscriptions/)
  })
})
