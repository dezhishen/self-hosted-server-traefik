import client from './client'

export interface ParamDef {
  name: string
  type: string
  label?: string
  description?: string
  required?: boolean
  default?: unknown
  options?: { label: string; value: string }[]
}

export interface PortMapping {
  host_port: number
  container_port: number
  protocol?: string
}

export interface ContainerConfig {
  image?: string
  env?: Record<string, string>
  ports?: PortMapping[]
  volumes?: { source: string; target: string; read_only?: boolean }[]
}

export interface Service {
  api_version?: string
  name: string
  description?: string
  image?: string
  category?: string
  params?: ParamDef[]
  container?: ContainerConfig
  tags?: string[]
}

export interface ServiceDetail {
  definition: Service
  status: string
}

export interface ServiceLogs {
  logs: string
}

export function listServices(keyword?: string): Promise<{ data: Service[] }> {
  return client.get('/services', { params: { query: keyword } })
}

export function getService(name: string): Promise<{ data: ServiceDetail }> {
  return client.get(`/services/${name}`)
}

export function installService(config: Record<string, unknown>): Promise<{ data: Service }> {
  return client.post('/services', config)
}

export function uninstallService(name: string): Promise<void> {
  return client.delete(`/services/${name}`)
}

export function restartService(name: string): Promise<void> {
  return client.post(`/services/${name}/restart`)
}

export function getServiceLogs(name: string, tail?: number): Promise<{ data: ServiceLogs }> {
  return client.post(`/services/${name}/logs`, { tail })
}
