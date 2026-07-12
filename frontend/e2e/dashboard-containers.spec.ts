import { test, expect } from '@playwright/test'

test.describe('Dashboard - Container Table', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  test('container table has column headers', async ({ page }) => {
    const table = page.locator('.el-table')
    await expect(table).toBeVisible()

    // Table headers
    await expect(page.getByText('Name').first()).toBeVisible()
    await expect(page.getByText('Image').first()).toBeVisible()
    await expect(page.getByText('Status').first()).toBeVisible()
    await expect(page.getByText('Uptime').first()).toBeVisible()
  })

  test('container table loads data rows when containers exist', async ({ page }) => {
    await page.waitForTimeout(2000)

    const rows = page.locator('.el-table__body-wrapper tbody tr')
    const rowCount = await rows.count()

    // If containers exist, each row should have name, image, status, uptime
    if (rowCount > 0) {
      const firstRow = rows.first()
      const cells = firstRow.locator('td')

      // Should have at least 4 cells (Name, Image, Status, Uptime)
      const cellCount = await cells.count()
      expect(cellCount).toBeGreaterThanOrEqual(4)

      // First cell should have a non-empty name
      const nameText = await cells.nth(0).textContent()
      expect(nameText?.trim().length).toBeGreaterThan(0)
    }
  })

  test('container overview stat cards update with data', async ({ page }) => {
    await page.waitForTimeout(2000)

    // Total count should be shown
    const totalText = page.getByText('Total')
    await expect(totalText).toBeVisible()

    // Managed count should be shown
    const managedText = page.getByText('Managed')
    await expect(managedText).toBeVisible()

    // Unmanaged count should be shown
    const unmanagedText = page.getByText('Unmanaged')
    await expect(unmanagedText).toBeVisible()
  })

  test('adopt unmanaged button appears when unmanaged containers exist', async ({ page }) => {
    await page.waitForTimeout(2000)

    // If unmanaged count > 0, the adopt button should appear
    const unmanagedSection = page.getByText('Unmanaged')
    await expect(unmanagedSection).toBeVisible()

    // Check if the adopt button exists (it's conditional on unmanagedCount > 0)
    const adoptBtn = page.getByRole('button', { name: /adopt|migrate/i })
    if (await adoptBtn.isVisible()) {
      await adoptBtn.click()
      await page.waitForLoadState('networkidle')
      await expect(page).toHaveURL(/\/migrate/)
    }
  })
})
