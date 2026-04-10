import { useState } from 'react'
import './App.css'

function App() {
  const [userRes, setUserRes] = useState<string>('')
  const [orderRes, setOrderRes] = useState<string>('')

  const testUserAPI = async () => {
    setUserRes('請求發送中...')
    try {
      const res = await fetch('/user/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          account: 'admin@admin.com', 
          password: '12345678',
          provider: 'email'
        })
      })
      const data = await res.json()
      setUserRes(JSON.stringify(data, null, 2))
    } catch (e: any) {
      setUserRes('連線失敗: ' + e.message)
    }
  }

  const testOrderAPI = async () => {
    setOrderRes('請求發送中...')
    try {
      const res = await fetch('/v1/order/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          amount: 0,
          order_no: "string",
          status: "string",
          user_id: 1
        })
      })
      const data = await res.json()
      setOrderRes(JSON.stringify(data, null, 2))
    } catch (e: any) {
      setOrderRes('連線失敗: ' + e.message)
    }
  }

  return (
    <div style={{ padding: '40px', fontFamily: 'sans-serif', maxWidth: '800px', margin: '0 auto' }}>
      <h1>🚀 Infar 微服務連線測試</h1>
      <p>目前採用最簡單的原生 fetch，驗證前端與後端 (User: 8888, Order: 8889) 的網路通道是否暢通。</p>

      <div style={{ marginBottom: '30px', border: '1px solid #ccc', padding: '20px', borderRadius: '8px' }}>
        <h2>🙋‍♂️ User Service (8888)</h2>
        <button onClick={testUserAPI} style={{ padding: '10px 20px', fontSize: '16px', cursor: 'pointer' }}>
          測試呼叫 [POST] /user/login
        </button>
        <pre style={{ background: '#2d2d2d', color: '#fff', padding: '15px', marginTop: '15px', borderRadius: '4px', overflowX: 'auto' }}>
          {userRes || '尚未發送請求...'}
        </pre>
      </div>

      <div style={{ border: '1px solid #ccc', padding: '20px', borderRadius: '8px' }}>
        <h2>📦 Order Service (8889)</h2>
        <button onClick={testOrderAPI} style={{ padding: '10px 20px', fontSize: '16px', cursor: 'pointer' }}>
          測試呼叫 [POST] /v1/order/create
        </button>
        <pre style={{ background: '#2d2d2d', color: '#fff', padding: '15px', marginTop: '15px', borderRadius: '4px', overflowX: 'auto' }}>
          {orderRes || '尚未發送請求...'}
        </pre>
      </div>
    </div>
  )
}

export default App
