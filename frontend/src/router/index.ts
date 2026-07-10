import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
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
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
