-- D1 schema for surrogate-1-cursor (replaces HF Space's filesystem cursor state)
-- Apply via: wrangler d1 execute surrogate-1-cursor --file=schema.sql
-- Or via API: POST /accounts/{acct}/d1/database/{uuid}/query

CREATE TABLE IF NOT EXISTS cursors (
    dataset_id  TEXT PRIMARY KEY,
    offset      INTEGER NOT NULL DEFAULT 0,
    total       INTEGER,
    last_batch  TEXT,
    updated_at  INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS datasets (
    slug          TEXT PRIMARY KEY,
    hf_id         TEXT NOT NULL,
    schema        TEXT,
    license       TEXT,
    score         REAL DEFAULT 0.5,
    cap           INTEGER DEFAULT 50000,
    downloads     INTEGER DEFAULT 0,
    discovered_ts INTEGER DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_datasets_score ON datasets(score DESC);
CREATE INDEX IF NOT EXISTS idx_cursors_updated ON cursors(updated_at);
