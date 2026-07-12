---
date: 2026-07-12
topic: "SSH Key Selector — endpoint key selection & authorize via existing key"
status: draft
---

## Problem Statement

Two blocking issues with the current SSH key management flow:

**Issue 1: Keygen auto-refreshes before key is authorized.** When a user generates or imports a key via `endpoint_name`, the handler sets `ssh_key_ref` and immediately calls `RefreshEndpoints()`. The new key's public key hasn't been installed on the remote server yet, so the SSH dialer fails with `unable to authenticate, attempted methods [none publickey]`. This floods logs with warnings but doesn't achieve anything — the user must still authorize the key separately.

**Issue 2: Authorize requires password auth (increasingly unavailable).** The `handleSSHAuthorize` handler connects to the remote SSH server using `gossh.Password(req.Password)`. Many hardened SSH servers disable password authentication (`PasswordAuthentication no` in `sshd_config`). When that's the case, the authorize step can never succeed — the user is stuck.

**Issue 3: No way to select an existing key from the store.** The frontend only offers "Generate" and "Import" buttons, which create new keys. There's no dropdown to pick from keys already in the key store (`GET /api/ssh/keys` already exists). Users who manually install their public key (via their own SSH session) have no way to select it in the dashboard.

## Constraints

- Backend: Go, Chi router, zap logger
- Frontend: Vue 3 + TypeScript, Element Plus, Pinia
- `sshKeyList()` API already exists on frontend (`GET /api/ssh/keys`)
- `handleSSHKeys` handler already exists on backend
- `SSHKeyManager` with full CRUD already exists
- Existing tests must pass after changes

## Approach

Three independent changes that together fix the workflow:

1. **Remove auto-Refresh from keygen/import handlers** — Let them save the key + update `ssh_key_ref`, but don't call `RefreshEndpoints()`. The user triggers reconnect by saving the endpoint form (`PUT /api/config` → `RefreshEndpoints()`).

2. **Add key selector dropdown to endpoint form** — Replace the static "configured/no key" display with an `<el-select>` backed by `sshKeyList()`. On selection change, update `ep.connection.ssh_key_ref` in the local state.

3. **Add key-based auth to authorize handler** — Allow the authorize request to optionally specify a `transport_key_ref`. If provided, use that key's private key to SSH into the remote (instead of password) and install the target key's public key.

---

## Architecture

### Change 1: Backend — keygen/import no longer auto-refresh

**File: `backend/internal/server/ssh.go`**

In both `handleSSHKeygen` and `handleSSHImport`, when `req.EndpointName` is set:
- Set `epCfg.Connection.SSHKeyRef = req.Name` (already done)
- Call `s.app.ConfigMgr.SaveEndpoints()` (already done)
- **Remove** the `s.app.RefreshEndpoints()` call
- Log that the key was assigned but the user needs to reconnect

The `RefreshEndpoints()` call at the end of `PUT /api/config` (`handleConfig`) remains — that's the user-triggered save action.

### Change 2: Frontend — key selector dropdown

**File: `frontend/src/views/EndpointList.vue`**

Replace the current SSH key section (lines 264-283) that shows configure/not-configured + Generate/Import buttons with:

```
[el-select : ssh_key_ref — list of available keys from sshKeyList()]
    ├── (no key selected)
    ├── key-name-1  [ed25519]  SHA256:xxxx
    ├── key-name-2  [rsa-4096] SHA256:yyyy
    └── key-name-3  [ed25519]  SHA256:zzzz

[Generate New Key button]  [Import Key button]
  — opens keygen dialog     — opens import dialog
  — on success, refresh      — on success, refresh
    key list & select new      key list & select new

[if ssh_key_ref is set]
  Type:   <el-tag>{{ keyInfo.type }}</el-tag>
  Fingerprint: {{ keyInfo.fingerprint }}
  Public Key:  [textarea readonly] [copy button]

[Authorize Remote button]  → opens authorize dialog
```

**Data flow:**
1. `onMounted` calls `sshKeyList()` → populates `sshKeys` ref
2. After keygen/import success, refresh `sshKeyList()` and auto-select the new key
3. On dropdown change, update `ep.connection.ssh_key_ref`
4. On endpoint type change away from SSH, clear `ssh_key_ref`

**State additions:**
- `sshKeys = ref<SSHKeyInfo[]>([])` — all keys from key store
- `loadSSHKeys()` — calls `sshKeyList()` and sorts by name

### Change 3: Backend — authorize via existing SSH key

**File: `backend/internal/server/ssh.go`**

Extend `authorizeRequest` to support `transport_key_ref`:

```go
type authorizeRequest struct {
    EndpointName    string `json:"endpoint_name"`
    KeyRef          string `json:"key_ref,omitempty"`          // target key to authorize
    TransportKeyRef string `json:"transport_key_ref,omitempty"` // existing key used as transport
    Password        string `json:"password,omitempty"`         // fallback if no transport key
}
```

**Modified authorize flow:**

```
1. Validate endpoint_name, resolve target key (KeyRef or endpoint's ssh_key_ref)
2. Determine auth method for transport connection:
   a. If TransportKeyRef is set:
      - Get the transport key's private key from SSHKeyManager
      - Use gossh.PublicKeys(signer) as auth method
   b. Else if Password is set:
      - Use gossh.Password(password) as auth method
   c. Else: return error "either transport_key_ref or password is required"
3. Connect to remote SSH server with chosen auth
4. Append target key's public key to ~/.ssh/authorized_keys
5. Call s.app.RefreshEndpoints() to reconnect with the now-authorized key
```

### Change 4: Frontend — authorize dialog with key transport option

**File: `frontend/src/views/EndpointList.vue`**

Extend the authorize dialog to let the user pick an existing key as transport:

```
[Authorize Remote: endpoint-name]

Method: ○ Use password        ○ Use existing SSH key

[if password selected]
  Password: [password input]

[if key transport selected]
  Transport Key: [el-select from sshKeys]
    (shows keys that have public_key set)

[Cancel] [Authorize]
```

---

## Data Flow

### Full workflow: "I have my own SSH key, I just want to select it"

```
1. User imports their personal SSH key via "Import" dialog
   → POST /api/ssh/import { name: "my-personal-key", private_key: "..." }
   → Backend saves to ssh_keys.yaml, updates endpoint's ssh_key_ref
   → Backend does NOT RefreshEndpoints (key isn't authorized yet... but wait)

   [Actually, if the user imports their OWN key that's already authorized
    on the remote server, we SHOULD reconnect. The problem is we can't
    tell the difference between "new key, not authorized" and "existing key,
    already authorized".]

   Decision: Only auto-refresh on import if the endpoint already has the
   same ssh_key_ref (i.e., user is re-importing the same key). For new
   assignments, let the user trigger refresh via save.
```

Actually, let me reconsider. The simplest and most correct approach:

**On keygen** — never auto-refresh. The key is brand new, it can't be authorized yet.

**On import** — never auto-refresh either. We can't know if the key is already authorized on the remote.

**On PUT /api/config** — always refresh. This is the explicit user save action.

**On authorize success** — always refresh. We just installed the public key, so the private key should work now.

This means the flow becomes:

```
Generate key → key appears in dropdown → user copies public key →
user SSHes into remote manually → pastes public key →
user goes back to dashboard → selects key from dropdown →
clicks "Save All" → PUT /api/config → RefreshEndpoints → connects ✅
```

OR for the authorize flow:

```
Generate key → key appears in dropdown → user clicks "Authorize Remote" →
either enters password OR selects an existing key as transport →
authorize handler installs public key → RefreshEndpoints → connects ✅
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Keygen + endpoint: key saved, ssh_key_ref set | No error — key is created, user sees it in dropdown. Endpoint runtime unchanged. |
| Keygen + endpoint not found | Warning logged, key still created. |
| Authorize: transport_key_ref not found | Error: "transport key not found" |
| Authorize: neither password nor transport key | Error: "password or transport_key_ref required" |
| Authorize: remote SSH connection fails | Error returned to user with SSH error details |
| Authorize: key install succeeds, RefreshEndpoints fails | Key IS authorized on remote. Refresh failure is logged but authorize response is still success. |
| PUT /api/config: ssh_key_ref points to missing key | Validation error: "SSH key not found" (already implemented) |

---

## Testing Strategy

### Backend tests (`backend/internal/server/ssh_test.go`)
- **Keygen without auto-refresh**: Verify that after keygen with endpoint_name, the endpoint config has `SSHKeyRef` set but no `RefreshEndpoints` was called (mock the app's endpoint map and verify it's unchanged)
- **Authorize with transport key**: Mock SSHKeyManager.GetPrivateKey, verify the SSH client config uses PublicKeys auth instead of Password
- **Authorize with transport key not found**: Verify proper error
- **Authorize with neither password nor transport key**: Verify proper error

### Frontend tests (if any)
- Key selector dropdown populated from `sshKeyList()`
- After keygen/import, dropdown auto-selects new key
- Changing dropdown updates `ep.connection.ssh_key_ref`
- Authorize dialog toggles between password and key transport

---

## Open Questions

1. **Should import auto-refresh if re-importing the same key?** I say no — simpler to never auto-refresh on import. The user clicks "Save All" to reconnect.

2. **How does the user know the endpoint is disconnected?** Currently the dashboard handles failed runtimes silently (warn log). We might want a visual indicator (red badge) on disconnected SSH endpoints, but that's scope for another iteration.

3. **Authorize dialog UX — should we default to key transport if keys exist?** Yes — if there are keys in the store with `public_key` set, default to "Use existing SSH key" and pre-select the first suitable key.
