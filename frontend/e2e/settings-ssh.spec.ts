import { test, expect } from '@playwright/test'

test.describe('Settings - SSH Keygen', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/settings')
    await page.waitForLoadState('networkidle')
  })

  test('SSH endpoint type reveals SSH fields', async ({ page }) => {
    // Change the first endpoint type to "ssh"
    const typeSelect = page.locator('.el-form-item').filter({ hasText: 'Type' }).locator('.el-select').first()
    await typeSelect.click()

    // Wait for the dropdown popper (teleported to body)
    const dropdown = page.locator('.el-select-dropdown').filter({ hasText: 'ssh' }).last()
    await dropdown.waitFor({ state: 'visible', timeout: 5000 })
    await dropdown.locator('span').filter({ hasText: 'ssh' }).click()

    // Now SSH User and SSH key management fields should be visible
    await expect(page.getByText('SSH User')).toBeVisible()
    await expect(page.getByText('SSH Key')).toBeVisible()

    // The Generate button should be visible
    const generateBtn = page.getByRole('button', { name: /Generate |Regenerate/ })
    await expect(generateBtn).toBeVisible()

    // The Import button should be visible
    await expect(page.getByRole('button', { name: 'Import Key' })).toBeVisible()
  })

  test('SSH keygen dialog opens and generates key', async ({ page }) => {
    // First switch to SSH type
    const typeSelect = page.locator('.el-form-item').filter({ hasText: 'Type' }).locator('.el-select').first()
    await typeSelect.click()
    const dropdown = page.locator('.el-select-dropdown').filter({ hasText: 'ssh' }).last()
    await dropdown.waitFor({ state: 'visible', timeout: 5000 })
    await dropdown.locator('span').filter({ hasText: 'ssh' }).click()
    await page.waitForTimeout(300)

    // Click Generate button to open dialog
    await page.getByRole('button', { name: 'Generate' }).click()
    await page.waitForTimeout(500)

    // Dialog should be visible
    const dialog = page.locator('.el-dialog').filter({ hasText: 'Generate SSH Key' })
    await expect(dialog).toBeVisible()

    // Fill in key name
    const nameInput = dialog.locator('.el-form-item').filter({ hasText: 'Key Name' }).locator('input')
    await nameInput.fill('e2e-test-key')

    // Click Generate button in dialog
    await dialog.getByRole('button', { name: 'Generate' }).click()
    await page.waitForTimeout(1000)

    // Dialog title changes to "SSH Key Generated"
    await expect(dialog.getByText('SSH Key Generated')).toBeVisible()

    // Public key should be visible (only textarea in result step)
    const pubKeyTextarea = dialog.locator('textarea')
    await expect(pubKeyTextarea).toBeVisible()
    const pubKeyContent = await pubKeyTextarea.inputValue()
    expect(pubKeyContent).toContain('ssh-ed25519')

    // Private key warning should NOT appear
    await expect(dialog.getByText('Private key will only be shown ONCE')).not.toBeVisible()

    // Fingerprint shown in the success alert
    await expect(dialog.getByText(/SHA256:/)).toBeVisible()

    // Done button to close
    const doneBtn = dialog.getByRole('button', { name: 'Done' })
    await expect(doneBtn).toBeVisible()
    await doneBtn.click()
    await page.waitForTimeout(500)
    await expect(dialog).not.toBeVisible()
  })

  test('SSH keygen with RSA key type', async ({ page }) => {
    // Switch to SSH
    const typeSelect = page.locator('.el-form-item').filter({ hasText: 'Type' }).locator('.el-select').first()
    await typeSelect.click()
    const dropdown = page.locator('.el-select-dropdown').filter({ hasText: 'ssh' }).last()
    await dropdown.waitFor({ state: 'visible', timeout: 5000 })
    await dropdown.locator('span').filter({ hasText: 'ssh' }).click()
    await page.waitForTimeout(300)

    // Open dialog
    await page.getByRole('button', { name: 'Generate' }).click()
    await page.waitForTimeout(500)

    const dialog = page.locator('.el-dialog').filter({ hasText: 'Generate SSH Key' })

    // Fill name
    await dialog.locator('.el-form-item').filter({ hasText: 'Key Name' }).locator('input').fill('e2e-rsa-key')

    // Select RSA 2048
    const keyTypeSelect = dialog.locator('.el-form-item').filter({ hasText: 'Key Type' }).locator('.el-select')
    await keyTypeSelect.click()
    const keyTypeDropdown = page.locator('.el-select-dropdown').filter({ hasText: 'RSA 2048' }).last()
    await keyTypeDropdown.waitFor({ state: 'visible', timeout: 5000 })
    await keyTypeDropdown.locator('span').filter({ hasText: 'RSA 2048' }).click()
    await page.waitForTimeout(200)

    // Generate
    await dialog.getByRole('button', { name: 'Generate' }).click()
    await page.waitForTimeout(2000)

    // Verify RSA public key (only textarea in result)
    const pubKeyTextarea = dialog.locator('textarea')
    await expect(pubKeyTextarea).toBeVisible()
    const pubKeyContent = await pubKeyTextarea.inputValue()
    expect(pubKeyContent).toContain('ssh-rsa')

    // Close
    await dialog.getByRole('button', { name: 'Done' }).click()
  })

  test('empty key name shows validation warning', async ({ page }) => {
    // Switch to SSH
    const typeSelect = page.locator('.el-form-item').filter({ hasText: 'Type' }).locator('.el-select').first()
    await typeSelect.click()
    const dropdown = page.locator('.el-select-dropdown').filter({ hasText: 'ssh' }).last()
    await dropdown.waitFor({ state: 'visible', timeout: 5000 })
    await dropdown.locator('span').filter({ hasText: 'ssh' }).click()
    await page.waitForTimeout(300)

    // Open dialog
    await page.getByRole('button', { name: 'Generate' }).click()
    await page.waitForTimeout(500)

    const dialog = page.locator('.el-dialog').filter({ hasText: 'Generate SSH Key' })

    // Leave name empty, click Generate
    await dialog.getByRole('button', { name: 'Generate' }).click()
    await page.waitForTimeout(300)

    // Should see a warning message (ElMessage)
    // The dialog should still be in the input state (not showing results)
    await expect(dialog.getByText('Key Name')).toBeVisible()
  })

  test('public key info appears in endpoint card after generation', async ({ page }) => {
    // Switch to SSH
    const typeSelect = page.locator('.el-form-item').filter({ hasText: 'Type' }).locator('.el-select').first()
    await typeSelect.click()
    const dropdown = page.locator('.el-select-dropdown').filter({ hasText: 'ssh' }).last()
    await dropdown.waitFor({ state: 'visible', timeout: 5000 })
    await dropdown.locator('span').filter({ hasText: 'ssh' }).click()
    await page.waitForTimeout(300)

    // Open dialog and generate key
    await page.getByRole('button', { name: 'Generate SSH Key' }).click()
    await page.waitForTimeout(500)

    const dialog = page.locator('.el-dialog').filter({ hasText: 'Generate SSH Key' })
    await dialog.locator('.el-form-item').filter({ hasText: 'Key Name' }).locator('input').fill('pubkey-test-key')
    await dialog.getByRole('button', { name: 'Generate' }).click()
    await page.waitForTimeout(1000)
    await dialog.getByRole('button', { name: 'Done' }).click()
    await page.waitForTimeout(500)

    // After closing the dialog, the endpoint card should show public key info
    await expect(page.getByText('Key Type')).toBeVisible()
    await expect(page.getByText('Fingerprint')).toBeVisible()
    await expect(page.getByText('Public Key')).toBeVisible()
    // The public key textarea should contain the SSH key
    const pubKeyArea = page.locator('.el-form-item').filter({ hasText: 'Public Key' }).locator('textarea')
    await expect(pubKeyArea).toBeVisible()
    const pubKeyContent = await pubKeyArea.inputValue()
    expect(pubKeyContent).toContain('ssh-ed25519')
    // Private key section shows "configured" instead of raw key
    await expect(page.getByText('configured')).toBeVisible()
    // Private key textarea should NOT exist in the SSH section
    await expect(page.getByText('ssh_private_key')).not.toBeVisible()
  })

  test('full flow: change type to SSH, generate key, and save config persists after refresh', async ({ page }) => {
    const keyName = `save-test-${Date.now()}`
    const sshUser = 'root'
    const sshEndpoint = '10.0.0.50:22'

    // Switch endpoint type to SSH
    const typeSelect = page.locator('.el-form-item').filter({ hasText: 'Type' }).locator('.el-select').first()
    await typeSelect.click()
    const typeDropdown = page.locator('.el-select-dropdown').filter({ hasText: 'ssh' }).last()
    await typeDropdown.waitFor({ state: 'visible', timeout: 5000 })
    await typeDropdown.locator('span').filter({ hasText: 'ssh' }).click()
    await page.waitForTimeout(300)

    // Fill in endpoint and SSH user
    const endpointInput = page.locator('.el-form-item').filter({ hasText: 'Endpoint' }).locator('input').first()
    await endpointInput.fill(sshEndpoint)
    const sshUserInput = page.locator('.el-form-item').filter({ hasText: 'SSH User' }).locator('input')
    await sshUserInput.fill(sshUser)

    // Generate a new SSH key
    await page.getByRole('button', { name: 'Generate SSH Key' }).click()
    await page.waitForTimeout(500)
    const dialog = page.locator('.el-dialog').filter({ hasText: 'Generate SSH Key' })
    await dialog.locator('.el-form-item').filter({ hasText: 'Key Name' }).locator('input').fill(keyName)
    await dialog.getByRole('button', { name: 'Generate' }).click()
    await page.waitForTimeout(1000)
    await dialog.getByRole('button', { name: 'Done' }).click()
    await page.waitForTimeout(500)

    // Click Save Config
    const saveBtn = page.getByRole('button', { name: /Save/i }).first()
    await expect(saveBtn).toBeEnabled()
    await saveBtn.click()
    await page.waitForTimeout(1000)

    // Verify success toast
    await expect(page.getByText('Config saved')).toBeVisible({ timeout: 5000 })

    // Verify the API returns the updated config WITHOUT ssh_private_key
    const apiResp = await page.request.get('/api/config')
    const apiData = await apiResp.json()
    expect(apiData.endpoints.default.connection.type).toBe('ssh')
    expect(apiData.endpoints.default.connection.endpoint).toBe(sshEndpoint)
    expect(apiData.endpoints.default.connection.ssh_private_key).toBeUndefined()
    expect(apiData.endpoints.default.connection.ssh_key_fingerprint).toBeTruthy()
    expect(apiData.endpoints.default.connection.ssh_public_key).toBeTruthy()
    expect(apiData.endpoints.default.connection.ssh_user).toBe(sshUser)

    // Now refresh the page to verify persistence
    await page.goto('/settings')
    await page.waitForLoadState('networkidle')

    // Verify the endpoint type is still SSH after page reload
    const typeFormItem = page.locator('.el-form-item').filter({ hasText: 'Type' }).first()
    await expect(typeFormItem).toContainText('ssh')

    // SSH fields should be visible since type is ssh
    await expect(page.getByText('SSH User')).toBeVisible()
    await expect(page.getByText('SSH Key')).toBeVisible()
  })
})
