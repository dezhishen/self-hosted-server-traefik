import { test, expect } from '@playwright/test'

test.describe('Dashboard - Quick Actions', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  test('dashboard quick actions card has settings button', async ({ page }) => {
    await expect(page.getByText('Quick Actions')).toBeVisible()
    await expect(page.getByRole('button', { name: /settings/i })).toBeVisible()
  })

  test('dashboard settings button navigates to settings page', async ({ page }) => {
    await page.getByRole('button', { name: /settings/i }).click()
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveURL(/\/settings/)
    await expect(page.locator('h2')).toContainText('Settings')
  })

  test('dashboard settings button is accessible when authenticated', async ({ page }) => {
    // The settings button should be visible in the quick actions section
    const settingsBtn = page.getByRole('button', { name: /settings/i })
    await expect(settingsBtn).toBeVisible()

    // Click it and verify navigation
    await settingsBtn.click()
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveURL(/\/settings/)
  })
})
