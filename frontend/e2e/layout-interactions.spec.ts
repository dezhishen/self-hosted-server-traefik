import { test, expect } from '@playwright/test'

test.describe('Layout Interactions', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
  })

  test.describe('Sidebar', () => {
    test('sidebar is visible on desktop', async ({ page }) => {
      const sidebar = page.locator('.sidebar-aside')
      await expect(sidebar).toBeVisible()
    })

    test('sidebar has collapse toggle button', async ({ page }) => {
      // The collapse toggle is inside .sidebar-logo, visible on desktop (md+)
      const collapseBtn = page.locator('.sidebar-logo .el-button.hidden\\.md\\:inline-flex')
      // There should be at least one collapse/expand button
      const count = await collapseBtn.count()
      expect(count).toBeGreaterThanOrEqual(1)
    })

    test('sidebar collapse changes width', async ({ page }) => {
      const sidebar = page.locator('.sidebar-aside')

      // Initial width should be expanded (w-[220px])
      await expect(sidebar).toHaveClass(/w-\[220px\]/)

      // Click the collapse toggle button
      // The fold icon button is visible when expanded
      const foldBtn = page.locator('.sidebar-logo .hidden\\.md\\:inline-flex').first()
      await foldBtn.click()
      await page.waitForTimeout(400) // transition: width 0.3s

      // After collapse, width should be w-[64px]
      await expect(sidebar).toHaveClass(/w-\[64px\]/)

      // Click expand to restore
      const expandBtn = page.locator('.sidebar-logo .hidden\\.md\\:inline-flex').first()
      await expandBtn.click()
      await page.waitForTimeout(400)
      await expect(sidebar).toHaveClass(/w-\[220px\]/)
    })

    test('collapsed sidebar hides text labels', async ({ page }) => {
      const sidebar = page.locator('.sidebar-aside')

      // Collapse sidebar
      await page.locator('.sidebar-logo .hidden\\.md\\:inline-flex').first().click()
      await page.waitForTimeout(400)

      // When collapsed, the logo text (SelfHosted) should be hidden (v-show="!isCollapsed")
      const logoText = page.locator('.sidebar-logo span').filter({ hasText: 'SelfHosted' })
      await expect(logoText).not.toBeVisible()
    })

    test('sidebar navigation items are clickable when collapsed', async ({ page }) => {
      // Collapse first
      await page.locator('.sidebar-logo .hidden\\.md\\:inline-flex').first().click()
      await page.waitForTimeout(400)

      // Click the Services menu item (icon-only mode)
      await page.getByRole('menuitem', { name: /services/i }).click()
      await page.waitForLoadState('networkidle')
      await expect(page).toHaveURL(/\/services/)
    })
  })

  test.describe('Theme Toggle', () => {
    test('dark mode toggle button is visible in header', async ({ page }) => {
      const header = page.locator('header')
      // Dark mode button shows moon (🌙) or sun (☀️) emoji
      await expect(header.locator('button').filter({ hasText: /☀️|🌙/ })).toBeVisible()
    })

    test('clicking dark mode toggle changes theme class on html', async ({ page }) => {
      const toggleBtn = page.locator('header button').filter({ hasText: /☀️|🌙/ })
      const html = page.locator('html')

      // Get current dark state
      const wasDark = await html.evaluate(el => el.classList.contains('dark'))

      // Toggle dark mode
      await toggleBtn.click()
      await page.waitForTimeout(300)

      // Check theme changed
      const isDarkNow = await html.evaluate(el => el.classList.contains('dark'))
      expect(isDarkNow).not.toBe(wasDark)

      // Toggle back to restore
      await toggleBtn.click()
      await page.waitForTimeout(300)
      const restored = await html.evaluate(el => el.classList.contains('dark'))
      expect(restored).toBe(wasDark)
    })
  })

  test.describe('Language Switcher', () => {
    test('language switcher button is visible in header', async ({ page }) => {
      const header = page.locator('header')
      // Language button shows '中' (when English) or 'EN' (when Chinese)
      await expect(header.locator('button').filter({ hasText: /^中$|^EN$/ })).toBeVisible()
    })

    test('clicking language switcher toggles locale', async ({ page }) => {
      const langBtn = page.locator('header button').filter({ hasText: /^中$|^EN$/ })

      // Get current language text
      const currentText = await langBtn.textContent()
      const wasEnglish = currentText?.trim() === '中' // '中' means currently English

      // Toggle language
      await langBtn.click()
      await page.waitForTimeout(300)

      // After toggle, the button text changes
      const newText = await langBtn.textContent()
      if (wasEnglish) {
        expect(newText?.trim()).toBe('EN') // Switched to Chinese, button shows 'EN'
      } else {
        expect(newText?.trim()).toBe('中') // Switched to English, button shows '中'
      }

      // Toggle back
      await langBtn.click()
      await page.waitForTimeout(300)
      const restoredText = await langBtn.textContent()
      expect(restoredText?.trim()).toBe(currentText?.trim())
    })

    test('language switch persists in localStorage', async ({ page }) => {
      const langBtn = page.locator('header button').filter({ hasText: /^中$|^EN$/ })
      const currentText = await langBtn.textContent()
      const wasEnglish = currentText?.trim() === '中'

      // Toggle
      await langBtn.click()
      await page.waitForTimeout(300)

      // Verify localStorage was updated
      const storedLocale = await page.evaluate(() => localStorage.getItem('selfhosted_locale'))
      if (wasEnglish) {
        expect(storedLocale).toBe('zh-CN')
      } else {
        expect(storedLocale).toBe('en')
      }

      // Restore
      await langBtn.click()
    })
  })

  test.describe('Header Endpoint Selector', () => {
    test('endpoint selector is visible in header', async ({ page }) => {
      const header = page.locator('header')
      const endpointSelect = header.locator('.el-select').first()
      await expect(endpointSelect).toBeVisible()
    })

    test('endpoint selector shows current endpoint name', async ({ page }) => {
      const header = page.locator('header')
      const endpointSelect = header.locator('.el-select').first()

      // The select should have a value (the current endpoint)
      const trigger = endpointSelect.locator('.el-select__wrapper')
      await expect(trigger).toBeVisible()
    })
  })

  test.describe('Breadcrumb', () => {
    test('breadcrumb is visible on dashboard', async ({ page }) => {
      await expect(page.locator('.el-breadcrumb')).toContainText('Dashboard')
    })

    test('breadcrumb updates when navigating', async ({ page }) => {
      await page.goto('/services')
      await page.waitForLoadState('networkidle')
      await expect(page.locator('.el-breadcrumb')).toContainText('Services')
    })
  })
})
