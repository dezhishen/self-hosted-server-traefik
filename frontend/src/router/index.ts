import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue')
  },
  {
    path: '/',
    name: 'Dashboard',
    component: () => import('@/views/Dashboard.vue')
  },
  {
    path: '/services',
    name: 'ServiceList',
    component: () => import('@/views/ServiceList.vue')
  },
  {
    path: '/services/:name',
    name: 'ServiceDetail',
    component: () => import('@/views/ServiceDetail.vue')
  },
  {
    path: '/subscriptions',
    name: 'SubscriptionList',
    component: () => import('@/views/SubscriptionList.vue')
  },
  {
    path: '/settings',
    name: 'Settings',
    component: () => import('@/views/Settings.vue')
  },
  {
    path: '/migrate',
    name: 'Migration',
    component: () => import('@/views/Migration.vue')
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Auth guard — checks localStorage directly (same source of truth as auth store)
const TOKEN_KEY = 'selfhosted_auth_token'

router.beforeEach((to) => {
  const hasToken = !!localStorage.getItem(TOKEN_KEY)

  if (to.name === 'Login' && hasToken) {
    return { name: 'Dashboard' }
  }

  if (to.name !== 'Login' && !hasToken) {
    return { name: 'Login' }
  }

  return true
})

export default router
