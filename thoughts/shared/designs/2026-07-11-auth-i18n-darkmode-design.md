date: 2026-07-11
topic: "Auth Login + i18n + Dark Mode"
status: draft

## Problem Statement

The app has three missing features that make it not production-ready:

1. **No login** — Anyone who reaches the HTTP port has full admin access. The backend stores a bcrypt password hash but never validates it. There's no login endpoint, no session/token, no auth middleware.
2. **No multi-language** — All UI text is hard-coded in English. International users and Chinese users (the primary audience based on GitHub README) can't use the app in their preferred language.
3. **No dark mode** — The app always renders in light mode. Users who prefer dark themes or work at night get eye strain. Some partial `dark:` Tailwind classes exist but no functional theme switching.

## Constraints

- **Single-user admin app** — Login is for the single admin user (username + password from config). No multi-user, no roles, no OAuth.
- **Simple backend session** — No Redis/JWT dependency. Use in-memory bearer tokens (crypto/rand, sync.Map). Survives server restart by requiring re-login.
- **Backward compatibility** — Existing endpoints and config format must not break. If no password is set, auth is optional (or we require one to be set).
- **No new Go dependencies** — crypto/rand, sync, encoding/hex, net/http are all stdlib. bcrypt already imported.

## Approach

I'm taking a layered approach: **backend auth first** (foundation), then **frontend login** (depends on auth), then **i18n + dark mode** (independent of each other, can be parallel).

### Auth Decision: Bearer Token, In-Memory

I considered session cookies but chose bearer tokens because:
- The frontend is an SPA (Vue) with Axios — bearer tokens are idiomatic
- No CSRF concerns with the `Authorization` header
- Simple to implement, no cookie config needed
- Frontend already has an Axios interceptor pattern

### i18n Decision: vue-i18n

Standard Vue ecosystem choice. Lazy-loaded locale files. Browser language detection.

### Dark Mode Decision: @vueuse/core useDark

Minimal code — `useDark` handles `prefers-color-scheme` media query + class toggle. Use Tailwind `dark:` variant + Element Plus dark CSS variables.

## Architecture

### Auth Flow

```
┌─────────┐     POST /api/auth/login      ┌──────────┐
│  Login   │  ──────────────────────────►  │  Backend  │
│  Page    │  {"username","password"}       │  Server   │
│          │  ◄──────────────────────────  │          │
│          │  {"token":"abc123..."}         │  - bcrypt│
└────┬─────┘                                │  verify  │
     │                                       │  session │
     │  Subsequent requests                   │  sync.Map│
     │  Authorization: Bearer abc123...       └──────────┘
     ▼
┌──────────┐
│ Protected │  Auth middleware checks
│  Pages    │  token in sync.Map
└──────────┘
```

**Session lifetime:** Until logout (`POST /api/auth/logout`) or server restart (in-memory).

### Route Organization

```
Public (no auth):
  GET  /api/auth/login      (POST only — no GET needed)
  GET  /api/health          (keep public for health checks)
  GET  /api/endpoints       (needed to show endpoint picker before login)

Protected (auth required):
  Everything else (config, services, containers, subscriptions, SSH, password)
```

## Components

### Backend — Session Manager (`backend/internal/server/auth.go`, new)

- `sessionManager` struct with `sync.Map` of `token → username`
- `generateToken() string` — 32-byte random hex
- `CreateSession(username string) (token string)`
- `ValidateSession(token string) (username string, ok bool)`
- `RevokeSession(token string)`

### Backend — Auth Handlers (in `server.go`)

- `handleAuthLogin` — POST `/api/auth/login`
  - Parse `{"username","password"}`
  - Load stored password hash from config
  - `bcrypt.CompareHashAndPassword`
  - Create session, return token
- `handleAuthLogout` — POST `/api/auth/logout`
  - Read token from `Authorization: Bearer ...`
  - Revoke session

### Backend — Auth Middleware (in `server.go`)

- `withAuth(next http.Handler) http.Handler`
  - Skip auth for: `/api/auth/`, `/api/health`, `/api/endpoints`
  - Extract Bearer token from `Authorization` header
  - Validate against session manager
  - If invalid: return 401 `{"error":"unauthorized"}`
  - If valid: set `X-Auth-Username` header for downstream handlers

### Frontend — Auth Store (`src/stores/auth.ts`)

- State: `token`, `username`, `authenticated`
- Actions: `login(username, password)`, `logout()`, `checkAuth()`
- Persist: Store token in `localStorage` key `selfhosted_auth_token`
- On app init: Read token from localStorage, validate on first API call

### Frontend — Router Guard (`src/router/index.ts`)

- `beforeEach` navigation guard:
  - If route is NOT `/login` and NOT authenticated → redirect to `/login`
  - If route IS `/login` and already authenticated → redirect to `/`

### Frontend — Login Page (`src/views/Login.vue`)

- Centered card layout with app logo
- Username input + password input + login button
- Loading state, error messages
- On success: store token, redirect to dashboard

### Frontend — Axios Interceptor (`src/api/client.ts`)

- Request interceptor: Add `Authorization: Bearer <token>` header if token exists
- Response interceptor: If 401 received, clear token, redirect to `/login`

### Frontend — i18n Setup (`src/i18n/index.ts`)

- Install `vue-i18n` with `createI18n`
- Supported locales: `en`, `zh-CN`
- Detection: `navigator.language` → fallback to `en`
- Override: localStorage key `selfhosted_locale`
- Locale files as `.json` imports

### Frontend — Locale Files

- `src/i18n/locales/en.json` — All English translations
- `src/i18n/locales/zh-CN.json` — All Chinese translations

### Frontend — Language Switcher

- In `SdSidebar.vue` or `SdLayout.vue` header area
- Dropdown or toggle button
- Calls `i18n.global.locale.value = 'zh-CN'`
- Persists to localStorage

### Frontend — Dark Mode Store (`src/stores/theme.ts`)

- Uses `@vueuse/core` `useDark()` + `useToggle()`
- Wraps in Pinia store for reactivity across components
- Persist preference to localStorage key `selfhosted_dark`
- Toggle dark mode class on `document.documentElement`

### Frontend — Dark Mode CSS (`src/styles/index.css`)

- CSS custom properties for each theme:
  ```css
  :root {
    --bg-primary: #ffffff;
    --bg-secondary: #f0f2f5;
    --text-primary: #303133;
    --text-secondary: #606266;
    --border-color: #dcdfe6;
  }
  .dark {
    --bg-primary: #1a1a2e;
    --bg-secondary: #16213e;
    --text-primary: #e0e0e0;
    --text-secondary: #a0a0a0;
    --border-color: #3a3a5c;
  }
  ```
- Import Element Plus dark mode CSS: `element-plus/theme-chalk/dark/css-vars.css`
- Update all component usages to use CSS variables instead of hard-coded colors

## Data Flow

### Login Flow
1. User lands on any protected route → router guard redirects to `/login`
2. Login page shows endpoint picker (fetch `/api/endpoints` — public) + login form
3. User submits → `POST /api/auth/login` → backend validates bcrypt → returns token
4. Frontend stores token in Pinia + localStorage, adds to Axios default headers
5. Router redirects to `/` (dashboard)
6. Subsequent API calls include `Authorization: Bearer <token>`

### Logout Flow
1. User clicks logout in sidebar
2. `POST /api/auth/logout` — backend removes session from sync.Map
3. Frontend clears token from store + localStorage + Axios headers
4. Router redirects to `/login`

### i18n Flow
1. App mounts → i18n detects `navigator.language` or reads localStorage override
2. Sets `locale` in vue-i18n
3. All components use `$t('key')` or `t('key')` for text
4. Language switcher changes locale → all reactive text updates immediately
5. Preference saved to localStorage

### Dark Mode Flow
1. App mounts → `useDark` checks `prefers-color-scheme` or localStorage override
2. Toggles `class="dark"` on `document.documentElement`
3. CSS custom properties switch values
4. Element Plus dark CSS variables activate via `.dark` selector
5. Toggle button in sidebar changes the value → `useDark().toggle()`

## Error Handling

### Auth
- **Wrong password**: Return 401 `{"error":"invalid credentials"}` — don't reveal whether username exists
- **No password set**: Login should fail with "no password configured; set one via CLI `passwd` command" — no guessable default
- **Expired/invalid token**: 401 response → frontend clears token, redirects to login
- **Missing Authorization header**: 401 `{"error":"missing authorization header"}`
- **Server restart**: All sessions lost → all clients get 401 → auto-redirect to login

### i18n
- Missing translation key → fallback to key name (shows developer what's missing)
- Unsupported locale → fallback to `en`
- Failed locale file load → fallback to `en`

### Dark Mode
- No error states (CSS feature)
- System preference unavailable → fallback to light mode
- Transition between modes should be smooth (CSS transition on theme properties)

## Testing Strategy

### Backend Auth
- Unit test: `sessionManager` — create, validate, revoke, invalid token
- Integration test: login with correct/incorrect password
- Integration test: protected routes return 401 without token
- Integration test: protected routes return 200 with valid token

### Frontend Login
- E2E test (Playwright): Visit app → redirected to login → login with credentials → see dashboard
- E2E test: Visit `/services` without token → redirected to login
- E2E test: Logout → redirected to login → can't access dashboard

### Frontend i18n
- E2E test: Switch to Chinese → verify Chinese text on dashboard
- E2E test: Switch back to English → verify English text
- E2E test: Reload page → language persists

### Frontend Dark Mode
- E2E test: Toggle dark mode → verify dark class on html element
- E2E test: Reload → dark mode persists
- Visual test: Screenshot comparison (manual for now)

## Implementation Order

```
Backend Auth (session + middleware + login/logout handlers)
  └── Frontend Auth (login page + store + router guard)
        ├── i18n (vue-i18n + locale files + language switcher)
        └── Dark Mode (useDark + CSS vars + toggle)
```

Tasks 1 and 2 are sequential (backend must work before frontend login).
Tasks 3 and 4 are independent and can be parallel after frontend auth is wired.

## Open Questions

1. Should `/api/endpoints` remain public? Yes — the login page needs to show the endpoint picker before login.
2. Should `/api/health` remain public? Yes — health checks and monitoring shouldn't require auth.
3. What if no password is set? Login should fail with a clear error. We could also block all API access until a password is set (via CLI).
4. Token expiry? Not for v1. Sessions live until logout or server restart. This is a single-user admin tool, not a multi-tenant SaaS.
