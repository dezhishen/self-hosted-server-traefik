import { defineConfig } from '@playwright/test'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const BACKEND_BIN = process.env.BACKEND_BIN || path.resolve(__dirname, '../bin/selfhosted-backend')
const DEV_CONFIG = process.env.DEV_CONFIG || path.resolve(__dirname, '../.selfhosted.dev')

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: 'html',
  timeout: 30000,
  use: {
    baseURL: 'http://localhost:5199',
    trace: 'on-first-retry',
  },
  webServer: [
    {
      command: `BACKEND_BIN=${BACKEND_BIN} ${BACKEND_BIN} -c ${DEV_CONFIG} --addr :18081`,
      port: 18081,
      reuseExistingServer: !process.env.CI,
      timeout: 10000,
    },
    {
      command: `npx vite --host 0.0.0.0 --port 5199 --strictPort`,
      port: 5199,
      reuseExistingServer: !process.env.CI,
      timeout: 10000,
      env: {
        VITE_API_PROXY: 'http://localhost:18081',
      },
    },
  ],
})
