-- Editable store catalog. Seeded with current defaults; admin updates overwrite
-- price / credit amounts. Existing rows are never replaced on migrate.

CREATE TABLE IF NOT EXISTS catalog_plans (
    id               TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    price_mmk        INTEGER NOT NULL,
    monthly_credits  INTEGER NOT NULL,
    description      TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS catalog_items (
    id          TEXT PRIMARY KEY,
    kind        TEXT NOT NULL,
    name        TEXT NOT NULL,
    price_mmk   INTEGER NOT NULL,
    credits     INTEGER NOT NULL DEFAULT 0,
    plan_id     TEXT NOT NULL DEFAULT '',
    sort_order  INTEGER NOT NULL DEFAULT 0
);

INSERT INTO catalog_plans (id, name, price_mmk, monthly_credits, description)
VALUES
    ('free', 'Free', 0, 20, 'Get started with 20 credits each month.'),
    ('pro_monthly', 'Pro — Monthly', 9900, 500, '500 credits every month.'),
    ('pro_yearly', 'Pro — Yearly', 99000, 500, '500 credits every month, best value yearly.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO catalog_items (id, kind, name, price_mmk, credits, plan_id, sort_order)
VALUES
    ('sub_pro_monthly', 'subscription', 'Pro — Monthly', 9900, 500, 'pro_monthly', 1),
    ('sub_pro_yearly', 'subscription', 'Pro — Yearly', 99000, 500, 'pro_yearly', 2),
    ('credits_100', 'credit_pack', '100 Credits', 2500, 100, '', 10),
    ('credits_300', 'credit_pack', '300 Credits', 6500, 300, '', 11),
    ('credits_1000', 'credit_pack', '1000 Credits', 19000, 1000, '', 12)
ON CONFLICT (id) DO NOTHING;
