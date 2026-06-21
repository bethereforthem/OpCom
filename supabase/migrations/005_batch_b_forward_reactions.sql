-- =============================================================
-- OpCom — Migration 005: Messaging Power Features, Batch B
-- (Forward messages + reactions)
-- Run in Supabase SQL Editor, after 001-004
-- =============================================================

-- Forwarding: a forwarded message is a fresh row (own sender_id, since the
-- forwarder — not the original author — actually sent this copy); this
-- column points back at the original message so clients can show
-- "Forwarded from {original sender}" by following it.
ALTER TABLE messages
    ADD COLUMN forwarded_from_id UUID REFERENCES messages(id) ON DELETE SET NULL;

CREATE TABLE message_reactions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id  UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji       TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (message_id, user_id)
);

CREATE INDEX idx_reactions_message ON message_reactions(message_id);

ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reactions_select_member" ON message_reactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM messages m
            JOIN conversation_members cm ON cm.conversation_id = m.conversation_id
            WHERE m.id = message_reactions.message_id
              AND cm.user_id = auth.uid()
              AND cm.left_at IS NULL
        )
    );

-- Note: like reply_to_id in 004, forwarded_from_id is a self-referencing FK
-- on messages and is NOT embedded via a nested PostgREST select — that was
-- found to resolve in the wrong direction. The forwarded-from preview is
-- fetched via an explicit application-code lookup instead.
