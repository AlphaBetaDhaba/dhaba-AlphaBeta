package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"os"
	"time"

	"github.com/go-redis/redis/v8"
)

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "orders-api",
	})
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	writeJSON(w, http.StatusOK, map[string]string{
		"service":  "orders-api",
		"version":  "1.0.0",
		"hostname": hostname,
	})
}

type createOrderRequest struct {
	Items []orderItem `json:"items"`
}

type createOrderResponse struct {
	OrderID     int64   `json:"order_id"`
	Status      string  `json:"status"`
	TotalAmount float64 `json:"total_amount"`
}

func createOrderHandler(db *sql.DB, redisClient *redis.Client, w http.ResponseWriter, r *http.Request) {
	var req createOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if len(req.Items) == 0 {
		http.Error(w, "items must not be empty", http.StatusBadRequest)
		return
	}

	var totalAmount float64
	for _, item := range req.Items {
		if item.Quantity <= 0 {
			http.Error(w, "quantity must be > 0", http.StatusBadRequest)
			return
		}
		if item.UnitPrice < 0 {
			http.Error(w, "unit_price must be >= 0", http.StatusBadRequest)
			return
		}
		totalAmount += float64(item.Quantity) * item.UnitPrice
	}

	orderID, err := insertOrder(db, totalAmount, req.Items)
	if err != nil {
		http.Error(w, "failed to create order", http.StatusInternalServerError)
		return
	}

	enqueueOrder(r.Context(), redisClient, orderID)

	writeJSON(w, http.StatusCreated, createOrderResponse{
		OrderID:     orderID,
		Status:      "new",
		TotalAmount: totalAmount,
	})
}

type orderRow struct {
	ID          int64   `json:"id"`
	Status      string  `json:"status"`
	TotalAmount float64 `json:"total_amount"`
	CreatedAt   string  `json:"created_at"`
}

func listOrdersHandler(db *sql.DB, w http.ResponseWriter, r *http.Request) {
	rows, err := db.QueryContext(r.Context(),
		`SELECT id, status, total_amount, created_at FROM orders ORDER BY created_at DESC LIMIT 20`,
	)
	if err != nil {
		http.Error(w, "failed to fetch orders", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	orders := []orderRow{}
	for rows.Next() {
		var o orderRow
		var createdAt time.Time
		if err := rows.Scan(&o.ID, &o.Status, &o.TotalAmount, &createdAt); err != nil {
			http.Error(w, "failed to scan order", http.StatusInternalServerError)
			return
		}
		o.CreatedAt = createdAt.UTC().Format(time.RFC3339)
		orders = append(orders, o)
	}
	if err := rows.Err(); err != nil {
		http.Error(w, "row iteration error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, orders)
}
