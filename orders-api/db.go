package main

import (
	"database/sql"
	"log"

	_ "github.com/lib/pq"
)

func initDB(dsn string) *sql.DB {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("db open error: %v", err)
	}
	if err := db.Ping(); err != nil {
		log.Fatalf("db ping error: %v", err)
	}
	log.Println("connected to postgres")
	return db
}

type orderItem struct {
	MenuItemID int64   `json:"menu_item_id"`
	Quantity   int     `json:"quantity"`
	UnitPrice  float64 `json:"unit_price"`
}

func insertOrder(db *sql.DB, totalAmount float64, items []orderItem) (int64, error) {
	tx, err := db.Begin()
	if err != nil {
		return 0, err
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	var orderID int64
	err = tx.QueryRow(
		`INSERT INTO orders (status, total_amount) VALUES ('new', $1) RETURNING id`,
		totalAmount,
	).Scan(&orderID)
	if err != nil {
		return 0, err
	}

	for _, item := range items {
		_, err = tx.Exec(
			`INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price) VALUES ($1, $2, $3, $4)`,
			orderID, item.MenuItemID, item.Quantity, item.UnitPrice,
		)
		if err != nil {
			return 0, err
		}
	}

	if err = tx.Commit(); err != nil {
		return 0, err
	}
	return orderID, nil
}
