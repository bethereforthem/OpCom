-- =============================================================
-- OpCom — Migration 008: Messaging Power Features, Batch E
-- (Scheduled messages + Disappearing messages)
-- Run in Supabase SQL Editor, after 001-007
-- =============================================================

-- Shared, conversation-level setting (unlike archive/mute, which are
-- per-user) — every member sees the same state.
ALTER TABLE conversations ADD COLUMN disappearing_duration_seconds INTEGER;

-- Computed at send-time from the conversation's setting above; only ever
-- set going forward, never retroactively.
ALTER TABLE messages ADD COLUMN expires_at TIMESTAMPTZ;
CREATE INDEX idx_messages_expires_at ON messages(expires_at) WHERE expires_at IS NOT NULL;

-- Compose now, deliver later. Invisible to everyone (including other
-- conversation members) until actually dispatched by the poller.
CREATE TABLE scheduled_messages (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            TEXT NOT NULL DEFAULT 'text'
                        CHECK (type IN ('text', 'image', 'audio', 'video', 'document')),
    content         TEXT,
    media_id        UUID,
    reply_to_id     UUID,
    send_at         TIMESTAMPTZ NOT NULL,
    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_scheduled_pending ON scheduled_messages(send_at) WHERE sent_at IS NULL;

ALTER TABLE scheduled_messages ENABLE ROW LEVEL SECURITY;
