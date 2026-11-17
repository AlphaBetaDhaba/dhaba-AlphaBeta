import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/menu': 'http://localhost:8001',
      '/orders': 'http://localhost:8002',
    }
  }
})
