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

export interface MigrationRequest {
  container_id: string
  service_name: string
  params: ParamValue[]
  remove_old: boolean
}

export function analyzeMigrations(): Promise<{ data: MigrationCandidate[] }> {
  return client.get('/migrate/analyze')
}

export function executeMigration(req: MigrationRequest): Promise<{ data: { container_id: string } }> {
  return client.post('/migrate/execute', req)
}

export interface GenerateTemplateRequest {
  container_id: string
  service_name: string
}

export interface GenerateTemplateResult {
  service_name: string
  file_path: string
}

export function generateTemplate(req: GenerateTemplateRequest): Promise<{ data: GenerateTemplateResult }> {
  return client.post('/migrate/generate', req)
}

export interface AdoptRequest {
  container_id: string
  service_name?: string
  version?: string
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
