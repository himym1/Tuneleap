CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT,
    password_hash TEXT NOT NULL,
    created_at DOUBLE PRECISION NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_uq
    ON users (lower(username));

CREATE TABLE IF NOT EXISTS refresh_tokens (
    jti TEXT PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at DOUBLE PRECISION NOT NULL,
    revoked BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS refresh_tokens_user_expires_idx
    ON refresh_tokens (user_id, expires_at);

CREATE TABLE IF NOT EXISTS profile (
    singleton SMALLINT PRIMARY KEY CHECK (singleton = 1),
    generation BIGINT NOT NULL,
    summary_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    generation BIGINT NOT NULL,
    mode TEXT NOT NULL DEFAULT 'fallback' CHECK (mode = 'fallback'),
    created_at BIGINT NOT NULL,
    expires_at BIGINT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'ended', 'expired')),
    refill_owner TEXT,
    refill_lease_until BIGINT,
    recent_json JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS candidates (
    candidate_id TEXT NOT NULL,
    session_id TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    generation BIGINT NOT NULL,
    rank BIGINT NOT NULL,
    recommendation_type TEXT NOT NULL,
    song_json JSONB NOT NULL,
    strong_identity TEXT NOT NULL,
    weak_identity TEXT NOT NULL,
    blocked BOOLEAN NOT NULL DEFAULT FALSE,
    served BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (session_id, candidate_id),
    UNIQUE (session_id, generation, rank)
);

CREATE TABLE IF NOT EXISTS feedback (
    id BIGSERIAL PRIMARY KEY,
    idempotency_key TEXT NOT NULL UNIQUE,
    generation BIGINT NOT NULL,
    session_id TEXT NOT NULL,
    candidate_id TEXT NOT NULL,
    event TEXT NOT NULL,
    song_json JSONB NOT NULL,
    strong_identity TEXT NOT NULL,
    weak_identity TEXT NOT NULL,
    created_at BIGINT NOT NULL,
    UNIQUE (generation, session_id, candidate_id, event)
);

CREATE INDEX IF NOT EXISTS idx_feedback_generation_event_identity
    ON feedback (generation, event, strong_identity);
CREATE INDEX IF NOT EXISTS idx_candidates_session_generation_blocked_rank
    ON candidates (session_id, generation, blocked, rank);
CREATE INDEX IF NOT EXISTS idx_sessions_generation_expires_at
    ON sessions (generation, expires_at);

CREATE TABLE IF NOT EXISTS data_migrations (
    name TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    details JSONB NOT NULL DEFAULT '{}'::jsonb
);

INSERT INTO profile(singleton, generation, summary_json, updated_at)
VALUES (1, 0, '{}'::jsonb, 0)
ON CONFLICT (singleton) DO NOTHING;
