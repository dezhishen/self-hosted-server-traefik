import { test, expect } from '@playwright/test'

test.describe('Authentication', () => {
  test.beforeEach(async ({ page }) => {
    // Clear any existing auth token to start from a clean state
    await page.evaluate(() => localStorage.removeItem('selfhosted_auth_token'))
  })

  test('auth guard redirects to /login when unauthenticated', async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveURL(/\/login/)
  })

  test('login page shows login form elements', async ({ page }) => {
    await page.goto('/login')
    await page.waitForLoadState('networkidle')

    await expect(page.locator('.login-title')).toContainText('SelfHosted')
    await expect(page.locator('input[type="text"]')).toBeVisible()
    await expect(page.locator('input[type="password"]')).toBeVisible()
    await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible()
  })

  test('login page does NOT show sidebar or header', async ({ page }) => {
    await page.goto('/login')
    await page.waitForLoadState('networkidle')

    // Login page renders without the layout shell
    await expect(page.locator('header')).not.toBeVisible()
    await expect(page.locator('.sidebar-aside')).not.toBeVisible()
  })

  test('login with empty fields shows validation error', async ({ page }) => {
    await page.goto('/login')
    await page.waitForLoadState('networkidle')

    await page.getByRole('button', { name: /sign in/i }).click()
    await expect(page.locator('.el-alert--error')).toBeVisible()
  })

  test('login with invalid credentials shows error alert', async ({ page }) => {
    await page.goto('/login')
    await page.waitForLoadState('networkidle')

    await page.locator('input[type="text"]').fill('admin')
    await page.locator('input[type="password"]').fill('wrong_password')
    await page.getByRole('button', { name: /sign in/i }).click()

    // Wait for API response
    await page.waitForTimeout(1000)

    // Error alert should appear after failed login
    const alert = page.locator('.el-alert--error')
    await expect(alert).toBeVisible()
  })

  test('successful login redirects to dashboard', async ({ page }) => {
    // Use the auth API directly to get valid credentials
    const resp = await page.request.post('/api/auth/login', {
      data: { username: 'admin', password: 'admin' }
    })

    test.skip(resp.status() !== 200, 'Auth API not available in this environment')

    await page.goto('/login')
    await page.waitForLoadState('networkidle')

    await page.locator('input[type="text"]').fill('admin')
    await page.locator('input[type="password"]').fill('admin')
    await page.getByRole('button', { name: /sign in/i }).click()
    await page.waitForLoadState('networkidle')

    // Should redirect to dashboard after successful login
    await expect(page).toHaveURL(/\/$/)
  })

  test('authenticated user can access dashboard directly', async ({ page }) => {
    // First login
    const resp = await page.request.post('/api/auth/login', {
      data: { username: 'admin', password: 'admin' }
    })
    test.skip(resp.status() !== 200, 'Auth API not available')

    const { token, username } = await resp.json()
    await page.evaluate(({ token, username }) => {
      localStorage.setItem('selfhosted_auth_token', token)
      localStorage.setItem('selfhosted_auth_username', username)
    }, { token, username })

    // Now navigate to dashboard directly
    await page.goto('/')
    await page.waitForLoadState('networkidle')
    await expect(page).toHaveURL(/\/$/)
  })

  test('logout clears session and redirects to login', async ({ page }) => {
    // Login first
    const resp = await page.request.post('/api/auth/login', {
      data: { username: 'admin', password: 'admin' }
    })
    test.skip(resp.status() !== 200, 'Auth API not available')

    const { token, username } = await resp.json()
    await page.evaluate(({ token, username }) => {
      localStorage.setItem('selfhosted_auth_token', token)
      localStorage.setItem('selfhosted_auth_username', username)
    }, { token, username })

    await page.goto('/')
    await page.waitForLoadState('networkidle')

    // Click user avatar to open dropdown
    const userBtn = page.locator('header').getByRole('button').filter({ hasText: username })
    await userBtn.click()

    // Click Logout from dropdown
    await page.getByRole('menuitem', { name: /logout/i }).click()
    await page.waitForLoadState('networkidle')

    // Should redirect to login
    await expect(page).toHaveURL(/\/login/)
  })
})
