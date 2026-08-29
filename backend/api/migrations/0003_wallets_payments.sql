-- Dual credit wallets + payment orders (manual-transfer proof → admin approve).

CREATE TABLE IF NOT EXISTS credit_wallets (
    user_id              TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    subscription_credits INTEGER NOT NULL DEFAULT 0,
    addon_credits        INTEGER NOT NULL DEFAULT 0,
    sub_period_ends_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_orders (
    id              TEXT PRIMARY KEY,
    user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_email      TEXT NOT NULL DEFAULT '',
    user_name       TEXT NOT NULL DEFAULT '',
    item_id         TEXT NOT NULL,
    kind            TEXT NOT NULL,
    item_name       TEXT NOT NULL,
    price_mmk       INTEGER NOT NULL,
    credits         INTEGER NOT NULL DEFAULT 0,
    plan_id         TEXT NOT NULL DEFAULT '',
    method          TEXT NOT NULL DEFAULT '',
    proof_upload_id TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending',
    admin_note      TEXT NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at     TIMESTAMPTZ,
    reviewed_by     TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON payment_orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_orders_user ON payment_orders(user_id, created_at DESC);
