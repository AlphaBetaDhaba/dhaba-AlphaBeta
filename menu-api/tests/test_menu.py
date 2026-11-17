from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from main import app


def make_client_with_mock_db(menu_rows=None):
    """Return a TestClient with a fake DB pool on app.state."""
    if menu_rows is None:
        menu_rows = []

    mock_conn = AsyncMock()
    mock_conn.fetch = AsyncMock(return_value=menu_rows)

    mock_pool = MagicMock()
    # acquire() used as async context manager
    mock_pool.acquire.return_value.__aenter__ = AsyncMock(return_value=mock_conn)
    mock_pool.acquire.return_value.__aexit__ = AsyncMock(return_value=False)

    app.state.db = mock_pool
    return TestClient(app)


def test_health():
    client = make_client_with_mock_db()
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "menu-api"


def test_menu_returns_list():
    # Build a minimal asyncpg-like row (plain dict suffices for subscript access)
    fake_row = {
        "id": 1,
        "name": "Nihari",
        "description": "Slow-cooked beef stew",
        "price": 450.00,
        "category": "Main Course",
        "is_available": True,
    }

    client = make_client_with_mock_db(menu_rows=[fake_row])
    response = client.get("/menu")
    assert response.status_code == 200
    items = response.json()
    assert isinstance(items, list)
    assert len(items) == 1
    assert items[0]["name"] == "Nihari"
    assert items[0]["price"] == 450.0
