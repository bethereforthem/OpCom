-- =============================================================
-- OpCom — Migration 006: Messaging Power Features, Batch C
-- (Mentions + search)
-- Run in Supabase SQL Editor, after 001-005
-- =============================================================

CREATE TABLE message_mentions (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id        UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    mentioned_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (message_id, mentioned_user_id)
);

CREATE INDEX idx_mentions_user ON message_mentions(mentioned_user_id);
CREATE INDEX idx_mentions_message ON message_mentions(message_id);

ALTER TABLE message_mentions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mentions_select_member" ON message_mentions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM messages m
            JOIN conversation_members cm ON cm.conversation_id = m.conversation_id
            WHERE m.id = message_mentions.message_id
              AND cm.user_id = auth.uid()
              AND cm.left_at IS NULL
        )
    );

-- Performance index for search (Batch C also adds GET /search/messages,
-- which uses plain ILIKE — this index just keeps that fast as data grows).
CREATE INDEX idx_messages_content_fts ON messages USING GIN (to_tsvector('english', content)) WHERE content IS NOT NULL;
