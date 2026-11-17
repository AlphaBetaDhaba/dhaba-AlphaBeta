function MenuList({ items, selectedItems, onQuantityChange }) {
  if (!items || items.length === 0) {
    return <p className="menu-empty">No menu items available.</p>
  }

  return (
    <div className="menu-grid">
      {items.map(item => (
        <div key={item.id} className="menu-card">
          <span className="menu-card-name">{item.name}</span>
          {item.description && (
            <span className="menu-card-desc">{item.description}</span>
          )}
          <span className="menu-card-price">PKR {item.price?.toLocaleString()}</span>
          <div className="menu-card-qty">
            <label htmlFor={`qty-${item.id}`}>Qty:</label>
            <input
              id={`qty-${item.id}`}
              type="number"
              min="0"
              max="10"
              value={selectedItems[item.id] || 0}
              onChange={e => onQuantityChange(item.id, Number(e.target.value))}
            />
          </div>
        </div>
      ))}
    </div>
  )
}

export default MenuList
