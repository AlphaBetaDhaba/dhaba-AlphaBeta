package main

import (
	"context"
	"log"

	"github.com/go-redis/redis/v8"
)

func initRedis(addr string) *redis.Client {
	client := redis.NewClient(&redis.Options{
		Addr: addr,
	})
	if err := client.Ping(context.Background()).Err(); err != nil {
		log.Fatalf("redis ping error: %v", err)
	}
	log.Println("connected to redis")
	return client
}

func enqueueOrder(ctx context.Context, client *redis.Client, orderID int64) {
	if err := client.RPush(ctx, "orders:pending", orderID).Err(); err != nil {
		log.Printf("redis enqueue error: %v", err)
	}
}
