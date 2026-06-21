-- =============================================================
-- OpCom — Migration 003: Call Logs
-- Run in Supabase SQL Editor
-- =============================================================

CREATE TABLE call_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
    caller_id       UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    callee_id       UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    type            TEXT NOT NULL CHECK (type IN ('audio', 'video')),
    status          TEXT NOT NULL DEFAULT 'initiated'
                        CHECK (status IN ('initiated', 'ringing', 'active', 'ended', 'rejected', 'missed', 'failed')),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    answered_at     TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    duration_seconds INT GENERATED ALWAYS AS (
                        CASE
                            WHEN answered_at IS NOT NULL AND ended_at IS NOT NULL
                            THEN EXTRACT(EPOCH FROM (ended_at - answered_at))::INT
                            ELSE NULL
                        END
                    ) STORED,
    ended_by        UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_call_logs_caller   ON call_logs(caller_id);
CREATE INDEX idx_call_logs_callee   ON call_logs(callee_id);
CREATE INDEX idx_call_logs_started  ON call_logs(started_at DESC);
CREATE INDEX idx_call_logs_conv     ON call_logs(conversation_id);

ALTER TABLE call_logs ENABLE ROW LEVEL SECURITY;

-- Users can see calls they were part of
CREATE POLICY "call_logs_participants" ON call_logs
    FOR SELECT USING (
        auth.uid() = caller_id OR auth.uid() = callee_id
    );
