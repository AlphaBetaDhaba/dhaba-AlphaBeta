function OrderForm({ selectedItems, menuItems, onPlaceOrder, orderResult, loading }) {
  const selectedEntries = Object.entries(selectedItems).filter(([, qty]) => qty > 0)
  const hasSelection = selectedEntries.length > 0

  const total = selectedEntries.reduce((sum, [id, qty]) => {
    const item = menuItems.find(m => String(m.id) === String(id))
    return sum + (item ? item.price * qty : 0)
  }, 0)

  return (
    <div className="order-form">
      <h2>Your Order</h2>

      {hasSelection ? (
        <div className="order-summary">
          <ul>
            {selectedEntries.map(([id, qty]) => {
              const item = menuItems.find(m => String(m.id) === String(id))
              if (!item) return null
              return (
                <li key={id}>
                  {item.name} × {qty} — PKR {(item.price * qty).toLocaleString()}
                </li>
              )
            })}
          </ul>
          <p className="order-total">Total: PKR {total.toLocaleString()}</p>
        </div>
      ) : (
        <p className="order-summary">Select items from the menu above.</p>
      )}

      <button
        className="btn-place-order"
        onClick={onPlaceOrder}
        disabled={!hasSelection || loading}
      >
        {loading ? 'Placing…' : 'Place Order'}
      </button>

      {orderResult && (
        <p className="order-result">{orderResult}</p>
      )}
    </div>
  )
}

export default OrderForm
