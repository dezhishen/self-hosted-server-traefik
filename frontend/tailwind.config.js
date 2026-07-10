/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{vue,ts,js}'
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#409EFF',
          50: '#ecf5ff',
          100: '#d9ecff',
          200: '#b3d8ff',
          300: '#8cc5ff',
          400: '#66b1ff',
          500: '#409EFF',
          600: '#337ecc',
          700: '#26609a',
          800: '#1a4367',
          900: '#0d2535'
        },
        success: {
          DEFAULT: '#67C23A',
          50: '#f0f9eb',
          100: '#e1f3d8',
          200: '#c2e7b0',
          300: '#a4db89',
          400: '#85ce61',
          500: '#67C23A',
          600: '#529b2e',
          700: '#3e7423',
          800: '#294e17',
          900: '#15270c'
        },
        warning: {
          DEFAULT: '#E6A23C',
          50: '#fdf6ec',
          100: '#faecd8',
          200: '#f5d9b0',
          300: '#f0c689',
          400: '#eab361',
          500: '#E6A23C',
          600: '#b88230',
          700: '#8a6124',
          800: '#5c4118',
          900: '#2e200c'
        },
        danger: {
          DEFAULT: '#F56C6C',
          50: '#fef0f0',
          100: '#fde2e2',
          200: '#fbc4c4',
          300: '#f9a7a7',
          400: '#f78989',
          500: '#F56C6C',
          600: '#c45656',
          700: '#934141',
          800: '#622b2b',
          900: '#311616'
        },
        info: {
          DEFAULT: '#909399',
          50: '#f4f4f5',
          100: '#e9e9eb',
          200: '#d3d4d6',
          300: '#bcbec2',
          400: '#a6a9ad',
          500: '#909399',
          600: '#73767b',
          700: '#56585c',
          800: '#3a3b3e',
          900: '#1d1d1f'
        }
      }
    }
  },
  plugins: []
}
