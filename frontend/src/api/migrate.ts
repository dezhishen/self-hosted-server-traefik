import client from './client'

export interface ContainerInfo {
  id: string
  name: string
  image: string
  status: string
  state: string
  env: Record<string, string>
  ports: { host_port: number; container_port: number; protocol?: string }[]
  labels: Record<string, string>
  mounts: { source: string; target: string; read_only?: boolean }[]
}

export interface ParamValue {
  name: string
  value: unknown
}

export interface MigrationCandidate {
  container: ContainerInfo
  matched_service: string
  services: string[]
  extracted_params: ParamValue[]
}

export function analyzeMigrations(): Promise<{ data: MigrationCandidate[] }> {
  return client.get('/migrate/analyze')
}

export interface GenerateAppRequest {
  container_id: string
  service_name: string
}

export interface GenerateAppResult {
  service_name: string
  file_path: string
}

export function generateApp(req: GenerateAppRequest): Promise<{ data: GenerateAppResult }> {
  return client.post('/migrate/generate', req)
}

export interface AdoptRequest {
  container_id: string
  service_name: string
  repo_name?: string
  version?: string
  params?: ParamValue[]
  rebuild?: boolean
}

export interface AdoptResult {
  container_id: string
  service_name: string
  endpoint: string
  labels: Record<string, string>
}

export function adoptContainer(req: AdoptRequest): Promise<{ data: AdoptResult }> {
  return client.post('/migrate/adopt', req)
}
