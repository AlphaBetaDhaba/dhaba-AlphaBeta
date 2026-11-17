-- =============================================================================
-- Dhaba Orders — PostgreSQL Database Schema
-- =============================================================================
-- This script initialises the core schema for the Dhaba Orders restaurant
-- ordering application.  It is idempotent: safe to run more than once because
-- every CREATE statement uses IF NOT EXISTS and INSERT statements use
-- ON CONFLICT DO NOTHING.
--
-- Tables
--   1. menu_items   – the restaurant's food catalogue
--   2. orders       – customer orders (header record)
--   3. order_items  – individual line items that belong to an order
--
-- Triggers
--   set_updated_at  – automatically stamps updated_at on every UPDATE to
--                     menu_items and orders
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. ENUM TYPE: order_status
--    Restricts order status to exactly three lifecycle values so application
--    code and the database agree on valid states.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') THEN
        CREATE TYPE order_status AS ENUM ('new', 'cooking', 'ready');
    END IF;
END
$$;


-- ---------------------------------------------------------------------------
-- 2. TABLE: menu_items
--    Stores every dish the restaurant offers.  Prices are stored as NUMERIC
--    (10,2) so there is no floating-point rounding error.  The is_available
--    flag lets staff hide a dish without deleting it.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS menu_items (
    id           SERIAL          PRIMARY KEY,

    -- Human-readable dish name; must be provided
    name         VARCHAR(150)    NOT NULL,

    -- Optional longer description shown to customers
    description  TEXT,

    -- Price in PKR; must be a non-negative value with up to 2 decimal places
    price        NUMERIC(10, 2)  NOT NULL
                     CONSTRAINT menu_items_price_non_negative CHECK (price >= 0),

    -- Broad grouping, e.g. 'Main Course', 'Bread', 'Appetiser'
    category     VARCHAR(100)    NOT NULL,

    -- When FALSE the dish is hidden from ordering (e.g. sold out)
    is_available BOOLEAN         NOT NULL DEFAULT TRUE,

    created_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  menu_items                IS 'Restaurant food catalogue.';
COMMENT ON COLUMN menu_items.price          IS 'Price in PKR; must be >= 0.';
COMMENT ON COLUMN menu_items.is_available   IS 'FALSE hides the dish from ordering without deleting it.';


-- ---------------------------------------------------------------------------
-- 3. TABLE: orders
--    One row per customer order.  The status column uses the order_status
--    enum so the database itself rejects any invalid state transition value.
--    total_amount is stored here for fast retrieval; it must equal the sum of
--    (quantity × unit_price) for all related order_items rows.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
    id           SERIAL          PRIMARY KEY,

    -- Lifecycle stage of the order; constrained by the order_status enum
    status       order_status    NOT NULL DEFAULT 'new',

    -- Denormalised total; must be non-negative
    total_amount NUMERIC(10, 2)  NOT NULL
                     CONSTRAINT orders_total_amount_non_negative CHECK (total_amount >= 0),

    created_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  orders              IS 'Customer order header records.';
COMMENT ON COLUMN orders.status       IS 'Allowed values: new | cooking | ready (enforced by enum).';
COMMENT ON COLUMN orders.total_amount IS 'Denormalised total in PKR; should equal SUM(quantity * unit_price) across order_items.';


-- ---------------------------------------------------------------------------
-- 4. TABLE: order_items
--    Each row is one dish line within an order.  unit_price is copied from
--    menu_items at the time of ordering so historical prices are preserved
--    even if the menu changes later.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_items (
    id           SERIAL          PRIMARY KEY,

    -- Parent order; cascades delete so removing an order cleans up its lines
    order_id     INTEGER         NOT NULL
                     REFERENCES orders(id) ON DELETE CASCADE,

    -- The dish that was ordered; set NULL if the menu item is later deleted
    menu_item_id INTEGER
                     REFERENCES menu_items(id) ON DELETE SET NULL,

    -- Must be at least 1; fractional quantities are not supported
    quantity     INTEGER         NOT NULL
                     CONSTRAINT order_items_quantity_positive CHECK (quantity > 0),

    -- Price locked in at order time; must be non-negative
    unit_price   NUMERIC(10, 2)  NOT NULL
                     CONSTRAINT order_items_unit_price_non_negative CHECK (unit_price >= 0)
);

COMMENT ON TABLE  order_items              IS 'Individual dish lines belonging to an order.';
COMMENT ON COLUMN order_items.unit_price   IS 'Price captured at order time; independent of future menu changes.';
COMMENT ON COLUMN order_items.menu_item_id IS 'NULL when the referenced menu item has been deleted.';


-- ---------------------------------------------------------------------------
-- 5. INDEXES
--    Created with IF NOT EXISTS (available since PG 9.5) so re-runs are safe.
--    Indexes target the columns most likely to appear in WHERE / ORDER BY
--    clauses in typical application queries.
-- ---------------------------------------------------------------------------

-- Look up all orders in a given status (e.g. the kitchen dashboard showing
-- all 'cooking' orders).
CREATE INDEX IF NOT EXISTS idx_orders_status
    ON orders (status);

-- Sort or filter orders by creation time (e.g. recent orders list).
CREATE INDEX IF NOT EXISTS idx_orders_created_at
    ON orders (created_at DESC);

-- Retrieve all line items for a specific order (very frequent join).
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items (order_id);

-- Look up all orders that contain a specific menu item (analytics / reports).
CREATE INDEX IF NOT EXISTS idx_order_items_menu_item_id
    ON order_items (menu_item_id);

-- Filter menu by category and availability (customer-facing menu query).
CREATE INDEX IF NOT EXISTS idx_menu_items_category_available
    ON menu_items (category, is_available);


-- ---------------------------------------------------------------------------
-- 6. TRIGGER FUNCTION: set_updated_at
--    A single reusable trigger function that sets NEW.updated_at to the
--    current transaction timestamp before any UPDATE completes.  Using one
--    shared function (rather than per-table functions) keeps the schema DRY.
--
--    CREATE OR REPLACE is used so re-running the script silently updates the
--    function body if it already exists, with no error.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Stamp the row with the current transaction time.
    -- CURRENT_TIMESTAMP is used (rather than NOW()) because it is the SQL
    -- standard form and both resolve to the same value inside a transaction.
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION set_updated_at() IS
    'Trigger function: sets updated_at to the current timestamp on every UPDATE.';


-- ---------------------------------------------------------------------------
-- 7. TRIGGERS: attach set_updated_at to menu_items and orders
--
--    The DO $$ ... $$ guard checks pg_trigger before attempting CREATE so
--    the script remains safe to run more than once.  (PostgreSQL does not
--    support CREATE TRIGGER IF NOT EXISTS before version 17, so the guard
--    is the portable alternative that works on PG 12–16 as well.)
--
--    BEFORE UPDATE means the timestamp is applied before the new row is
--    written to disk — the most efficient and correct placement.
--    FOR EACH ROW ensures the function fires once per modified row.
-- ---------------------------------------------------------------------------

-- Trigger on menu_items
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_trigger
        WHERE  tgname   = 'trg_menu_items_set_updated_at'
        AND    tgrelid  = 'menu_items'::regclass
    ) THEN
        CREATE TRIGGER trg_menu_items_set_updated_at
            BEFORE UPDATE ON menu_items
            FOR EACH ROW
            EXECUTE FUNCTION set_updated_at();
    END IF;
END
$$;

-- Trigger on orders
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_trigger
        WHERE  tgname   = 'trg_orders_set_updated_at'
        AND    tgrelid  = 'orders'::regclass
    ) THEN
        CREATE TRIGGER trg_orders_set_updated_at
            BEFORE UPDATE ON orders
            FOR EACH ROW
            EXECUTE FUNCTION set_updated_at();
    END IF;
END
$$;


-- ---------------------------------------------------------------------------
-- 8. SAMPLE DATA — Pakistani restaurant menu
--    ON CONFLICT DO NOTHING makes this block idempotent; re-running the
--    script will not duplicate rows.  The conflict target is the primary key
--    so we temporarily override the sequence to use fixed IDs.
-- ---------------------------------------------------------------------------

INSERT INTO menu_items (id, name, description, price, category, is_available)
VALUES
    (1, 'Chicken Karahi',
        'Tender chicken cooked in a spiced tomato and ginger gravy in a traditional karahi.',
        850.00, 'Main Course', TRUE),

    (2, 'Chicken Biryani',
        'Fragrant basmati rice layered with spiced chicken, caramelised onions and fresh herbs.',
        450.00, 'Rice Dishes', TRUE),

    (3, 'Daal Mash',
        'Slow-cooked white lentils tempered with garlic, cumin and dried red chillies.',
        250.00, 'Main Course', TRUE),

    (4, 'Seekh Kebab',
        'Minced beef blended with herbs and spices, skewered and grilled over charcoal.',
        600.00, 'Appetiser', TRUE),

    (5, 'Roti',
        'Freshly baked whole-wheat flatbread from the tandoor.',
        30.00, 'Bread', TRUE),

    (6, 'Naan',
        'Soft leavened bread brushed with butter, baked in the tandoor.',
        50.00, 'Bread', TRUE)

ON CONFLICT (id) DO NOTHING;

-- Advance the sequence to the highest of:
--   a) the current sequence value (so a re-run never rewinds it), and
--   b) the highest ID present in the table (covers the seed rows).
-- Using GREATEST prevents ID collisions if rows have been added after the
-- seed data was first inserted, because setval with a plain MAX(id) would
-- otherwise reset the sequence below its current position.
SELECT setval(
    'menu_items_id_seq',
    GREATEST(
        (SELECT last_value FROM menu_items_id_seq),
        (SELECT MAX(id)   FROM menu_items)
    )
);
