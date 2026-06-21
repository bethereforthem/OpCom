-- =============================================================
-- OpCom — Migration 007: Messaging Power Features, Batch D
-- (Archive conversations + Mute conversations)
-- Run in Supabase SQL Editor, after 001-006
-- =============================================================

-- Per-user, per-conversation state — lives on the membership row so
-- one member archiving/muting a chat never affects anyone else's view of it.
ALTER TABLE conversation_members
    ADD COLUMN archived_at TIMESTAMPTZ,
    ADD COLUMN is_muted    BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN muted_until TIMESTAMPTZ;
