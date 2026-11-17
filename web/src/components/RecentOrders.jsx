function statusBadgeClass(status) {
  switch (status?.toLowerCase()) {
    case 'new':     return 'badge badge-new'
    case 'cooking': return 'badge badge-cooking'
    case 'ready':   return 'badge badge-ready'
    default:        return 'badge badge-default'
  }
}

function formatDate(dateStr) {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleString()
}

function RecentOrders({ orders }) {
  if (!orders || orders.length === 0) {
    return <p className="orders-empty">No orders yet.</p>
  }

  return (
    <div className="orders-table-wrap">
      <table className="orders-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Status</th>
            <th>Total (PKR)</th>
            <th>Created</th>
          </tr>
        </thead>
        <tbody>
          {orders.map(order => (
            <tr key={order.id}>
              <td>#{order.id}</td>
              <td>
                <span className={statusBadgeClass(order.status)}>
                  {order.status}
                </span>
              </td>
              <td>{order.total_amount?.toLocaleString()}</td>
              <td>{formatDate(order.created_at)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default RecentOrders
