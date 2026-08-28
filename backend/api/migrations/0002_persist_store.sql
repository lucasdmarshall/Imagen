-- Additions needed by the Postgres-backed store (idempotent; safe to re-run).

-- Approval gate + Google/passwordless accounts.
ALTER TABLE users ADD COLUMN IF NOT EXISTS approved BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users ALTER COLUMN password_hash SET DEFAULT '';

-- Sessions carry an explicit expiry (opaque bearer tokens).
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Idempotency: cached responses for mutating requests.
CREATE TABLE IF NOT EXISTS idempotency_keys (
    key        TEXT PRIMARY KEY,
    status     INTEGER NOT NULL,
    body       BYTEA   NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Uploaded reference photos (dev/small-scale: stored in the DB).
CREATE TABLE IF NOT EXISTS uploads (
    id           TEXT PRIMARY KEY,
    user_id      TEXT NOT NULL,
    content_type TEXT NOT NULL DEFAULT '',
    data         BYTEA NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_uploads_user ON uploads(user_id, created_at);
