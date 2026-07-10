import client from './client'

export interface RuntimeInfo {
  engine: string
  version: string
  os: string
  arch: string
  cpus: number
  memory: string
}

export interface Container {
  id: string
  name: string
  image: string
  status: string
  state: string
  created_at: string
  ports?: { host_port: number; container_port: number; protocol?: string }[]
  labels?: Record<string, string>
}

export function getRuntimeInfo(): Promise<{ data: RuntimeInfo }> {
  return client.get('/health')
}

export function listContainers(all = true): Promise<{ data: Container[] }> {
  return client.get('/containers', { params: { all: String(all) } })
}
