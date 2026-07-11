import { createI18n } from 'vue-i18n'
import en from './locales/en.json'
import zhCN from './locales/zh-CN.json'

// Check localStorage for saved preference
const savedLocale = localStorage.getItem('selfhosted_locale')

// Detect browser language
const browserLang = navigator.language

let locale = 'en'
if (savedLocale) {
  locale = savedLocale
} else if (browserLang.startsWith('zh')) {
  locale = 'zh-CN'
}

export default createI18n({
  legacy: false,
  locale,
  fallbackLocale: 'en',
  messages: {
    en,
    'zh-CN': zhCN
  }
})
