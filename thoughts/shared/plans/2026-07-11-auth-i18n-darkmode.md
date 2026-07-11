# Auth + i18n + Dark Mode Implementation Plan

## Dependency Order

```
Phase 1 (Backend Auth) → Phase 2 (Frontend Login) → Phase 3 (i18n) + Phase 4 (Dark Mode) in parallel
```

---

## Phase 1: Backend Auth

### Task 1.1: Create Session Manager

**File:** `backend/internal/server/auth.go` (NEW)

**Content:**
- `sessionManager` struct with `sync.Map` of `token → username`
- `newSessionManager() *sessionManager`
- `generateToken() string` — 32 bytes from `crypto/rand`, hex-encoded
- `CreateSession(username string) (token string)`
- `ValidateSession(token string) (username string, ok bool)`
- `RevokeSession(token string)`

**Dependencies:** None

**Verification:** `go build ./backend/internal/server/...`

---

### Task 1.2: Add Auth Handlers + Middleware

**File:** `backend/internal/server/server.go` (MODIFY)

**Changes:**
- Add `sessionManager` field to `Server` struct
- Init `sessionManager` in `New(app)`
- Add `handleAuthLogin` handler:
  - POST `/api/auth/login`
  - Parse `{"username":"...","password":"..."}` JSON body
  - If `s.app.Config.Auth` is nil or `PasswordHash` is empty → 403 `{"error":"no password configured"}`
  - `bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))` → fail → 401 `{"error":"invalid credentials"}`
  - Success → `s.sessions.CreateSession(username)` → return `{"token":"...","username":"..."}`
- Add `handleAuthLogout` handler:
  - POST `/api/auth/logout`
  - Extract Bearer token from `Authorization` header
  - `s.sessions.RevokeSession(token)` → 200 `{"status":"ok"}`
- Add `withAuth` middleware:
  - Skip paths: `/api/auth/`, `/api/health`, `/api/endpoints`
  - Extract `Authorization: Bearer <token>` header
  - `s.sessions.ValidateSession(token)` → fail → 401 `{"error":"unauthorized"}`
  - Pass username downstream via context or header
- Wire `withAuth` into `Handler()`: `h.withLogging(h.withAuth(mux))`
- Register new routes: `POST /api/auth/login`, `POST /api/auth/logout`

**Imports needed:** `crypto/rand`, `encoding/hex`, `golang.org/x/crypto/bcrypt` (already in go.mod)

**Dependencies:** Task 1.1

**Verification:** `go build ./backend/internal/server/...`

---

## Phase 2: Frontend Login

### Task 2.1: Create Auth Pinia Store

**File:** `frontend/src/stores/auth.ts` (NEW)

**Content:**
- Pinia store `useAuthStore`
- State: `token: string | null`, `username: string | null`, `loading: boolean`
- Getter: `authenticated` (token !== null)
- Actions:
  - `login(username, password)` — POST `/api/auth/login`, store token + username, save to localStorage
  - `logout()` — POST `/api/auth/logout`, clear token from state + localStorage
  - `initFromStorage()` — read `selfhosted_auth_token` + `selfhosted_auth_username` from localStorage on app start
- localStorage keys: `selfhosted_auth_token`, `selfhosted_auth_username`

**Dependencies:** Phase 1 complete

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 2.2: Add Auth Axios Interceptor

**File:** `frontend/src/api/client.ts` (MODIFY)

**Changes:**
- Import `useAuthStore` (with Pinia workaround — use direct module-level store access pattern like `currentRemote.ts`)
- Request interceptor: if token exists, add `Authorization: Bearer <token>` header
- Response interceptor: on 401 response, call `authStore.logout()`, redirect to `/login`
- Export `setAuthToken(token)` function (same module-level pattern as `setCurrentRemote`)

**Dependencies:** Task 2.1

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 2.3: Add Login Route + Auth Guard

**File:** `frontend/src/router/index.ts` (MODIFY)

**Changes:**
- Add route: `{ path: '/login', name: 'Login', component: () => import('@/views/Login.vue') }`
- Add `beforeEach` navigation guard:
  - If route name is `Login` and already authenticated → redirect to `/`
  - If route name is NOT `Login` and NOT authenticated → redirect to `/login`
- Import `useAuthStore` (handle Pinia outside setup — use `createPinia()` then `setActivePinia()` pattern)

**Dependencies:** Task 2.1

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 2.4: Create Login Page

**File:** `frontend/src/views/Login.vue` (NEW)

**Content:**
- Centered full-screen layout (flex, min-h-screen)
- Card with app logo (from `@/assets/logo.svg`), app name "SelfHosted"
- Remote endpoint selector (reuse RemoteSelect logic or show inline dropdown)
- Username input (el-input with prepend icon)
- Password input (el-input type="password" with show-password)
- Login button (el-button type="primary", full width, loading state)
- Error message display (el-alert type="error", shown on failed login)
- On success: `router.push('/')`
- Uses `useAuthStore().login()`

**Dependencies:** Tasks 2.1, 2.3

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 2.5: Add Login/Logout to Sidebar

**File:** `frontend/src/components/SdSidebar.vue` (MODIFY)

**Changes:**
- Show login button at bottom of sidebar when NOT authenticated (hidden when already showing collapse toggle)
- Show username + logout button at bottom of sidebar when authenticated
- Logout calls `authStore.logout()` → redirect to `/login`

**Dependencies:** Task 2.1

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 2.6: Initialize Auth in main.ts

**File:** `frontend/src/main.ts` (MODIFY)

**Changes:**
- Import `useAuthStore`
- Call `authStore.initFromStorage()` after creating Pinia
- Optionally: if no token, router should guard — but we handle via router guard

**Dependencies:** Tasks 2.1, 2.3

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

## Phase 3: i18n

### Task 3.1: Install vue-i18n Dependency

**File:** `frontend/package.json` (MODIFY)

**Changes:** Add `"vue-i18n": "^9.14.0"` to dependencies

**Verification:** `cd frontend && pnpm install`

---

### Task 3.2: Create Locale Files

**File:** `frontend/src/i18n/locales/en.json` (NEW)

**Content:** Complete English translation map for all UI strings:
- Navigation: Dashboard, Services, Subscriptions, Settings, Login, Logout
- Dashboard: engine info, containers stats, overview
- Services: list, detail tabs (Info, Status, Logs), install, uninstall, restart
- Subscriptions: list, add, remove, sync
- Settings: config, endpoints, TLS, SSH, password
- Common: loading, error, success, cancel, confirm, save, close, search
- Auth: Login, Password, Username, "No password configured", "Invalid credentials"
- Theme: "Dark mode", "Light mode"
- Language: "Language", "English", "Chinese"

**Dependencies:** None

**Verification:** Valid JSON, no duplicate keys

---

### Task 3.3: Create Chinese Locale File

**File:** `frontend/src/i18n/locales/zh-CN.json` (NEW)

**Content:** Chinese (Simplified) translations matching en.json keys

**Dependencies:** Task 3.2 (same key structure)

**Verification:** Same keys as en.json

---

### Task 3.4: Create i18n Setup

**File:** `frontend/src/i18n/index.ts` (NEW)

**Content:**
- Import `createI18n` from `vue-i18n`
- Import `en` and `zh-CN` locale objects
- Detect language: `navigator.language` → check if starts with `zh` → use `zh-CN`, else `en`
- Check localStorage `selfhosted_locale` for override
- Create and export i18n instance with `legacy: false` (composition API mode)
- Set fallback locale to `en`

**Dependencies:** Tasks 3.2, 3.3

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 3.5: Install i18n in main.ts

**File:** `frontend/src/main.ts` (MODIFY)

**Changes:**
- Import i18n instance from `@/i18n`
- `app.use(i18n)` before mount

**Dependencies:** Task 3.4

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 3.6: Add Language Switcher to Sidebar

**File:** `frontend/src/components/SdSidebar.vue` (MODIFY)

**Changes:**
- Add language toggle button or dropdown at bottom of sidebar (above theme toggle)
- Toggle between `en` and `zh-CN`
- Use `useI18n().locale` to switch
- Save preference to localStorage `selfhosted_locale`

**Dependencies:** Task 3.4

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 3.7: Translate All Views and Components

**Files:** All `.vue` files in `frontend/src/` (views + components)

**Changes:**
- Replace hard-coded text strings with `$t('key')` in template, `t('key')` in script
- Specifically: App.vue, SdLayout.vue, SdSidebar.vue, RemoteSelect.vue, SdCard.vue, SdButton.vue, SdInput.vue, SdSelect.vue, SdDialog.vue, SdTable.vue, SdStatus.vue, Dashboard.vue, ServiceList.vue, ServiceDetail.vue, SubscriptionList.vue, Settings.vue, Login.vue

**Dependencies:** Task 3.5

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

## Phase 4: Dark Mode

### Task 4.1: Install @vueuse/core

**File:** `frontend/package.json` (MODIFY)

**Changes:** Add `"@vueuse/core": "^11.0.0"` to dependencies

**Verification:** `cd frontend && pnpm install`

---

### Task 4.2: Create Theme Store

**File:** `frontend/src/stores/theme.ts` (NEW)

**Content:**
- Pinia store `useThemeStore`
- Uses `useDark()` from `@vueuse/core` (with `storageKey: 'selfhosted_dark'`)
- Uses `useToggle(isDark)` for the toggle action
- Export `isDark` ref and `toggleDark` function
- On init: `useDark()` reads `prefers-color-scheme` media query + localStorage

**Dependencies:** Task 4.1

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 4.3: Add Dark Mode CSS Variables

**File:** `frontend/src/styles/index.css` (MODIFY)

**Changes:**
- Add CSS custom properties for both themes:
  ```css
  :root {
    --bg-primary: #ffffff;
    --bg-secondary: #f0f2f5;
    --bg-card: #ffffff;
    --text-primary: #303133;
    --text-secondary: #606266;
    --text-placeholder: #c0c4cc;
    --border-color: #dcdfe6;
    --sidebar-bg: #1d1e1f;
    --sidebar-text: #bfcbd9;
    --sidebar-active-bg: #409eff;
    --sidebar-width: 220px;
    --header-height: 60px;
    --content-bg: #f0f2f5;
  }
  
  .dark {
    --bg-primary: #1a1a2e;
    --bg-secondary: #16213e;
    --bg-card: #1e2a4a;
    --text-primary: #e0e0e0;
    --text-secondary: #a0a0a0;
    --text-placeholder: #666666;
    --border-color: #3a3a5c;
    --content-bg: #0f0f23;
  }
  ```
- Update existing `:root` variables to use the new custom properties
- Add smooth color transitions: `*, *::before, *::after { transition: background-color 0.3s, color 0.3s, border-color 0.3s; }`

**Dependencies:** None

**Verification:** CSS compiles (included in build)

---

### Task 4.4: Import Element Plus Dark CSS

**File:** `frontend/src/main.ts` (MODIFY)

**Changes:**
- Import `element-plus/theme-chalk/dark/css-vars.css` after the main Element Plus CSS
- Import theme store and initialize it

**Dependencies:** Task 4.2

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 4.5: Add Dark Mode Toggle to Sidebar

**File:** `frontend/src/components/SdSidebar.vue` (MODIFY)

**Changes:**
- Add dark mode toggle button (moon/sun icon) at bottom of sidebar
- Uses `themeStore.toggleDark()`
- Show moon icon in light mode, sun icon in dark mode

**Dependencies:** Task 4.2

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

### Task 4.6: Update Components for Dark Mode

**Files:** All `.vue` files using hard-coded colors (SdLayout, SdSidebar, SdStatus, RemoteSelect, Dashboard, ServiceDetail, Settings, Login)

**Changes:**
- Replace hard-coded color values with CSS variable references
- Add Tailwind `dark:` variants where appropriate
- Remove hard-coded `background-color="#1d1e1f"` on sidebar el-menu (use CSS class with variable)
- Update SdLayout content area to use `var(--content-bg)`
- Update status colors to be visible in dark mode
- Update el-table, el-card, el-dialog backgrounds for dark mode via Element Plus dark CSS

**Dependencies:** Tasks 4.3, 4.4

**Verification:** `cd frontend && npx vue-tsc --noEmit`

---

## Build Verification (final)

```bash
# Backend
cd backend && go build ./... && go vet ./... && go test ./...

# Frontend
cd frontend && pnpm build

# Full project
cd .. && go build ./backend/... && go vet ./backend/...
```
