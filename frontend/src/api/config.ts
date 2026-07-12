import client from './client'

export interface AuthConfig {
  username: string
}

export interface TLSConfig {
  enabled: boolean
  ca_cert?: string
  cert?: string
  key?: string
  skip_verify?: boolean
}

export interface ConnectionConfig {
  type: string
  endpoint: string
  engine?: string
  tls?: TLSConfig
  ssh_user?: string
  /** References a key in the SSH key store */
  ssh_key_ref?: string
  /** Resolved from key store, read-only via GET /api/config */
  ssh_key_fingerprint?: string
  ssh_key_type?: string
  ssh_public_key?: string
}

export interface SSHKeyInfo {
  name: string
  type: string
  fingerprint: string
  public_key: string
}

export interface EndpointConfig {
  name: string
  connection: ConnectionConfig
  default: boolean
}

export interface AppConfig {
  base_data_dir?: string
  auth?: AuthConfig
  endpoints: Record<string, EndpointConfig>
  app_repos?: { name: string; url: string; enabled: boolean }[]
}

export function getConfig(): Promise<{ data: AppConfig }> {
  return client.get('/config')
}

export function updateConfig(cfg: AppConfig): Promise<void> {
  return client.put('/config', cfg)
}

export interface SSHKeygenResult {
  key_name: string
  public_key: string
  fingerprint: string
  type: string
}

export function sshKeygen(name: string, type = 'ed25519', endpointName?: string): Promise<{ data: SSHKeygenResult }> {
  const body: Record<string, string> = { name, type }
  if (endpointName) body.endpoint_name = endpointName
  return client.post('/ssh/keygen', body)
}

export function sshKeyImport(name: string, privateKey: string, endpointName?: string): Promise<{ data: SSHKeygenResult }> {
  const body: Record<string, string> = { name, private_key: privateKey }
  if (endpointName) body.endpoint_name = endpointName
  return client.post('/ssh/import', body)
}

export function sshKeyList(): Promise<{ data: SSHKeyInfo[] }> {
  return client.get('/ssh/keys')
}

export function sshKeyDelete(name: string): Promise<void> {
  return client.delete(`/ssh/keys/${name}`)
}

export function sshAuthorize(endpointName: string, password?: string, keyRef?: string, transportKeyRef?: string): Promise<void> {
  const body: Record<string, string> = { endpoint_name: endpointName }
  if (password) body.password = password
  if (keyRef) body.key_ref = keyRef
  if (transportKeyRef) body.transport_key_ref = transportKeyRef
  return client.post('/ssh/authorize', body)
}

export function changePassword(password: string): Promise<void> {
  return client.post('/config/password', { password })
}
