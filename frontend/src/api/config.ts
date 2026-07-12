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
  /** Never sent or received via JSON — server-side only */
  ssh_private_key?: never
  /** Computed from private key, read-only via GET /api/config */
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
  subscriptions?: { name: string; url: string; enabled: boolean }[]
}

export function getConfig(): Promise<{ data: AppConfig }> {
  return client.get('/config')
}

export function updateConfig(cfg: AppConfig): Promise<void> {
  return client.put('/config', cfg)
}

export interface SSHKeygenResult {
  name: string
  key_name: string
  public_key: string
  fingerprint: string
  type: string
}

export function sshKeygen(endpointName: string, name: string, type = 'ed25519'): Promise<{ data: SSHKeygenResult }> {
  return client.post('/ssh/keygen', { endpoint_name: endpointName, name, type })
}

export function sshKeyImport(endpointName: string, privateKey: string): Promise<{ data: SSHKeygenResult }> {
  return client.post('/ssh/import', { endpoint_name: endpointName, private_key: privateKey })
}

export function sshKeyList(): Promise<{ data: SSHKeyInfo[] }> {
  return client.get('/ssh/keys')
}

export function sshAuthorize(endpointName: string, password: string): Promise<void> {
  return client.post('/ssh/authorize', { endpoint_name: endpointName, password })
}

export function changePassword(password: string): Promise<void> {
  return client.post('/config/password', { password })
}
