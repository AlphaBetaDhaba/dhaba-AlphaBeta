import { useState, useEffect } from 'react'
import MenuList from './components/MenuList.jsx'
import OrderForm from './components/OrderForm.jsx'
import RecentOrders from './components/RecentOrders.jsx'

function App() {
  const [menuItems, setMenuItems] = useState([])
  const [selectedItems, setSelectedItems] = useState({}) // { id: quantity }
  const [recentOrders, setRecentOrders] = useState([])
  const [orderResult, setOrderResult] = useState('')
  const [loading, setLoading] = useState(false)

  const fetchMenu = async () => {
    try {
      const res = await fetch('/menu')
      const data = await res.json()
      setMenuItems(data)
    } catch (err) {
      console.error('Failed to fetch menu:', err)
    }
  }

  const fetchOrders = async () => {
    try {
      const res = await fetch('/orders')
      const data = await res.json()
      setRecentOrders(data)
    } catch (err) {
      console.error('Failed to fetch orders:', err)
    }
  }

  useEffect(() => {
    fetchMenu()
    fetchOrders()
  }, [])

  const handleQuantityChange = (id, qty) => {
    setSelectedItems(prev => {
      const updated = { ...prev }
      if (qty <= 0) {
        delete updated[id]
      } else {
        updated[id] = qty
      }
      return updated
    })
  }

  const handlePlaceOrder = async () => {
    setLoading(true)
    setOrderResult('')

    const items = Object.entries(selectedItems).map(([id, quantity]) => {
      const menuItem = menuItems.find(m => String(m.id) === String(id))
      return {
        menu_item_id: Number(id),
        quantity,
        unit_price: menuItem ? menuItem.price : 0,
      }
    })

    try {
      const res = await fetch('/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items }),
      })

      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.detail || `Error ${res.status}`)
      }

      setOrderResult('✅ Order placed successfully!')
      setSelectedItems({})
      await fetchOrders()
    } catch (err) {
      setOrderResult(`❌ ${err.message}`)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>🍛 Dhaba Orders</h1>
        <p className="tagline">Fresh Pakistani cuisine, delivered to your table</p>
      </header>

      <main className="app-main">
        <section>
          <h2>Menu</h2>
          <MenuList
            items={menuItems}
            selectedItems={selectedItems}
            onQuantityChange={handleQuantityChange}
          />
        </section>

        <section>
          <OrderForm
            selectedItems={selectedItems}
            menuItems={menuItems}
            onPlaceOrder={handlePlaceOrder}
            orderResult={orderResult}
            loading={loading}
          />
        </section>

        <section>
          <h2>Recent Orders</h2>
          <RecentOrders orders={recentOrders} />
        </section>
      </main>
    </div>
  )
}

export default App
