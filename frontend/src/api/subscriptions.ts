import client from './client'

export interface Subscription {
  name: string
  url: string
  enabled: boolean
  auto_update: boolean
}

export function listSubscriptions(): Promise<{ data: Subscription[] }> {
  return client.get('/subscriptions')
}

export function addSubscription(sub: Partial<Subscription>): Promise<{ data: Subscription }> {
  return client.post('/subscriptions', sub)
}

export function removeSubscription(name: string): Promise<void> {
  return client.delete(`/subscriptions/${name}`)
}

export function syncSubscription(name: string): Promise<void> {
  return client.post(`/subscriptions/${name}/sync`)
}
