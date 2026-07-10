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
