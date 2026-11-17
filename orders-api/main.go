package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func main() {
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbName := getEnv("DB_NAME", "dhaba")
	dbUser := getEnv("DB_USER", "dhaba")
	dbPassword := getEnv("DB_PASSWORD", "dhaba")
	redisAddr := getEnv("REDIS_ADDR", "localhost:6379")
	port := getEnv("PORT", "8002")

	dsn := fmt.Sprintf(
		"host=%s port=%s dbname=%s user=%s password=%s sslmode=disable",
		dbHost, dbPort, dbName, dbUser, dbPassword,
	)

	db := initDB(dsn)
	defer db.Close()

	redisClient := initRedis(redisAddr)
	defer redisClient.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/info", infoHandler)
	mux.HandleFunc("/orders", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			createOrderHandler(db, redisClient, w, r)
		case http.MethodGet:
			listOrdersHandler(db, w, r)
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	handler := corsMiddleware(mux)

	log.Printf("orders-api listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}
