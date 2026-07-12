import client from './client'

export interface AppRepo {
  name: string
  url: string
  enabled: boolean
  auto_update: boolean
}

export function listAppRepos(): Promise<{ data: AppRepo[] }> {
  return client.get('/app-repos')
}

export function addAppRepo(repo: Partial<AppRepo>): Promise<{ data: AppRepo }> {
  return client.post('/app-repos', repo)
}

export function removeAppRepo(name: string): Promise<void> {
  return client.delete(`/app-repos/${name}`)
}

export function syncAppRepo(name: string): Promise<void> {
  return client.post(`/app-repos/${name}/sync`)
}
