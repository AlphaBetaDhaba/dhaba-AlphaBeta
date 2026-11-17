# Dhaba Orders

Dhaba Orders is a demonstration multi-service restaurant ordering app built with a polyglot microservices architecture. It lets customers browse a Pakistani restaurant menu, place orders, and track their status in real time. Each service is implemented in a different language/framework to showcase how independent services communicate over HTTP and Redis.

---

## Architecture

```
                    ┌──────────────────────────────────────┐
                    │          Browser / React UI          │
                    │          web  :3000                  │
                    └────────┬─────────────┬───────────────┘
                             │             │
                   GET /menu │             │ POST/GET /orders
                             ▼             ▼
                    ┌──────────────┐  ┌──────────────┐
                    │  menu-api   │  │  orders-api  │
                    │  Python     │  │  Go          │
                    │  :8001      │  │  :8002       │
                    └──────┬──────┘  └──────┬───────┘
                           │                │
                           │ SQL            │ SQL + RPUSH
                           ▼                ▼
                    ┌────────────┐   ┌──────────────┐
                    │ PostgreSQL │   │    Redis      │
                    │  :5432     │◄──│    :6379      │
                    └─────▲──────┘   └──────┬───────┘
                          │                 │ BLPOP orders:pending
                          │          ┌──────▼───────┐
                          │          │kitchen-worker│
                          └──────────│  Java        │
                       UPDATE status │  (no port)   │
                                     └──────────────┘
                    ┌──────────────┐
                    │  stats-api  │
                    │  PHP/Laravel│
                    │  :8003      │
                    └──────┬──────┘
                           │ SQL (read-only aggregates)
                           ▼
                    ┌────────────┐
                    │ PostgreSQL │
                    │  :5432     │
                    └────────────┘
```

---

## Services

| Service        | Language / Framework | Port | Purpose                          |
|----------------|----------------------|------|----------------------------------|
| web            | React + Vite         | 3000 | Customer-facing UI               |
| menu-api       | Python + FastAPI     | 8001 | Menu catalogue                   |
| orders-api     | Go                   | 8002 | Order creation & listing         |
| kitchen-worker | Java + Spring Boot   | —    | Order processing worker          |
| stats-api      | PHP + Laravel        | 8003 | Aggregated statistics            |

---

## Prerequisites

Make sure the following are installed before you start:

| Tool              | Minimum Version |
|-------------------|-----------------|
| Node.js           | 20+             |
| Python            | 3.11+           |
| Go                | 1.22+           |
| Java              | 21+             |
| Maven             | 3.9+            |
| PHP               | 8.2+            |
| Composer          | 2+              |
| PostgreSQL        | 15+             |
| Redis             | 7+              |

---

## Database Setup

1. Create the database and user:

   ```sql
   -- Run as the postgres superuser
   CREATE USER dhaba WITH PASSWORD 'dhaba';
   CREATE DATABASE dhaba OWNER dhaba;
   ```

   ```bash
   sudo -u postgres psql -c "CREATE USER dhaba WITH PASSWORD 'dhaba';"
   sudo -u postgres psql -c "CREATE DATABASE dhaba OWNER dhaba;"
   ```

2. Load the schema and seed data:

   ```bash
   psql -U dhaba -d dhaba -f database/init.sql
   ```

---

## Running Services Locally

Open a separate terminal for each service.

### web

```bash
cd web
npm install
npm run dev        # http://localhost:3000
```

The Vite dev server proxies `/menu` → `:8001` and `/orders` → `:8002` automatically.

---

### menu-api

```bash
cd menu-api
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
DB_HOST=localhost DB_NAME=dhaba DB_USER=dhaba DB_PASSWORD=dhaba \
  uvicorn main:app --port 8001 --reload
```

API available at <http://localhost:8001>. Docs at <http://localhost:8001/docs>.

---

### orders-api

```bash
cd orders-api
go mod tidy
DB_HOST=localhost DB_NAME=dhaba DB_USER=dhaba DB_PASSWORD=dhaba \
  REDIS_ADDR=localhost:6379 go run .
```

API available at <http://localhost:8002>.

---

### kitchen-worker

```bash
cd kitchen-worker
mvn spring-boot:run \
  -Dspring-boot.run.jvmArguments="\
    -DDB_HOST=localhost -DDB_NAME=dhaba \
    -DDB_USER=dhaba -DDB_PASSWORD=dhaba \
    -DREDIS_HOST=localhost"
```

The worker runs in the background with no HTTP port. It processes orders from the `orders:pending` Redis list and writes a heartbeat to `kitchen:heartbeat` every 10 seconds.

---

### stats-api

```bash
cd stats-api
composer install
cp .env.example .env && php artisan key:generate
php artisan serve --port=8003
```

Update `DB_*` values in `.env` to match your local PostgreSQL credentials. API available at <http://localhost:8003>.

---

## Running Tests

```bash
# menu-api
cd menu-api && pytest

# orders-api
cd orders-api && go test ./...

# kitchen-worker
cd kitchen-worker && mvn test

# stats-api
cd stats-api && php artisan test
```

---

## Environment Variables

| Variable      | Service(s)                      | Default         | Description                              |
|---------------|---------------------------------|-----------------|------------------------------------------|
| `DB_HOST`     | menu-api, orders-api, kitchen-worker, stats-api | `localhost` | PostgreSQL host              |
| `DB_PORT`     | menu-api                        | `5432`          | PostgreSQL port                          |
| `DB_NAME`     | menu-api, orders-api, kitchen-worker | `dhaba`    | PostgreSQL database name                 |
| `DB_USER`     | menu-api, orders-api, kitchen-worker | `dhaba`    | PostgreSQL username                      |
| `DB_PASSWORD` | menu-api, orders-api, kitchen-worker | `dhaba`    | PostgreSQL password                      |
| `REDIS_ADDR`  | orders-api                      | `localhost:6379`| Redis address (`host:port`)              |
| `REDIS_HOST`  | kitchen-worker                  | `localhost`     | Redis hostname (port fixed to 6379)      |
| `APP_KEY`     | stats-api                       | *(generated)*   | Laravel application key (`php artisan key:generate`) |
| `APP_ENV`     | stats-api                       | `local`         | Laravel environment                      |

> **Tip:** For stats-api, all Laravel config lives in `.env` (copied from `.env.example`). Set `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` there.

---

## Redis Keys

| Key                 | Type   | Purpose                                                        |
|---------------------|--------|----------------------------------------------------------------|
| `orders:pending`    | List   | Queue of pending order IDs — `RPUSH` by orders-api, `BLPOP` by kitchen-worker |
| `kitchen:heartbeat` | String | Last heartbeat timestamp from kitchen-worker (TTL: 30 s)      |

---

## Project Structure

```
Dhaba/
├── database/
│   └── init.sql                   # Schema + seed data
├── kitchen-worker/                # Java + Spring Boot
│   ├── pom.xml
│   └── src/
│       ├── main/
│       │   ├── java/com/dhaba/kitchenworker/
│       │   │   ├── KitchenWorkerApplication.java
│       │   │   ├── OrderProcessor.java
│       │   │   └── HeartbeatService.java
│       │   └── resources/
│       │       └── application.properties
│       └── test/
│           └── java/com/dhaba/kitchenworker/
│               └── OrderProcessorTest.java
├── menu-api/                      # Python + FastAPI
│   ├── main.py
│   ├── requirements.txt
│   └── tests/
│       └── test_menu.py
├── orders-api/                    # Go
│   ├── go.mod
│   ├── go.sum
│   ├── main.go
│   ├── db.go
│   ├── redis.go
│   ├── handlers.go
│   └── handlers_test.go
├── stats-api/                     # PHP + Laravel
│   ├── artisan
│   ├── composer.json
│   ├── .env.example
│   └── bootstrap/
│       └── app.php
└── web/                           # React + Vite
    ├── index.html
    ├── package.json
    ├── vite.config.js
    └── src/
        ├── main.jsx
        ├── App.jsx
        ├── App.css
        └── components/
            ├── MenuList.jsx
            ├── OrderForm.jsx
            └── RecentOrders.jsx
```
