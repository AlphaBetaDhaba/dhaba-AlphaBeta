import os
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "dhaba")
DB_USER = os.getenv("DB_USER", "dhaba")
DB_PASSWORD = os.getenv("DB_PASSWORD", "dhaba")


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db = await asyncpg.create_pool(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )
    yield
    await app.state.db.close()


app = FastAPI(title="menu-api", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "menu-api"}


@app.get("/menu")
async def get_menu():
    try:
        async with app.state.db.acquire() as conn:
            rows = await conn.fetch(
                "SELECT id, name, description, price, category, is_available "
                "FROM menu_items WHERE is_available = true ORDER BY category, name"
            )
        return [
            {
                "id": row["id"],
                "name": row["name"],
                "description": row["description"],
                "price": float(row["price"]),
                "category": row["category"],
                "is_available": row["is_available"],
            }
            for row in rows
        ]
    except Exception:
        raise HTTPException(status_code=503, detail="Database unavailable")
