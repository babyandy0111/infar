import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      // 將 /user 開頭的請求代理到 User 服務 (8888)
      '/user': {
        target: 'http://127.0.0.1:8888',
        changeOrigin: true,
      },
      // 將 /v1/order 開頭的請求代理到 Order 服務 (8889)
      '/v1/order': {
        target: 'http://127.0.0.1:8889',
        changeOrigin: true,
      }
    }
  }
})
