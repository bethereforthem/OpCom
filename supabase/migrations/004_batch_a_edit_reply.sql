-- =============================================================
-- OpCom — Migration 004: Messaging Power Features, Batch A
-- (Message editing + reply system support)
-- Run in Supabase SQL Editor, after 001-003
-- =============================================================

-- Message editing: track whether/when a message was edited.
-- NULL = never edited.
ALTER TABLE messages
    ADD COLUMN edited_at TIMESTAMPTZ;

-- Internal/forensic record of prior content on each edit. Not exposed
-- through any "view history" UI yet — exists so that capability can be
-- added later without another migration.
CREATE TABLE message_edit_history (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id   UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    prev_content TEXT,
    edited_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_edit_history_message ON message_edit_history(message_id);

ALTER TABLE message_edit_history ENABLE ROW LEVEL SECURITY;

-- Same visibility as the parent message: any active member of its conversation
CREATE POLICY "edit_history_select_member" ON message_edit_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM messages m
            JOIN conversation_members cm ON cm.conversation_id = m.conversation_id
            WHERE m.id = message_edit_history.message_id
              AND cm.user_id = auth.uid()
              AND cm.left_at IS NULL
        )
    );

-- Note: reply support needs no schema change — messages.reply_to_id already
-- exists (001_initial_schema.sql) and is already accepted by send_message.
-- This migration only adds the query embeds needed to surface it, which
-- live in application code, not the database.
