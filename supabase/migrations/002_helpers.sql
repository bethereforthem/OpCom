-- =============================================================
-- OpCom — Migration 002: Helper Functions
-- Run in Supabase SQL Editor after 001_initial_schema.sql
-- =============================================================

-- Find an existing private conversation between two users.
-- Used to prevent duplicate private conversations being created.
CREATE OR REPLACE FUNCTION find_private_conversation(user_a UUID, user_b UUID)
RETURNS TABLE(id UUID, type TEXT, name TEXT, created_at TIMESTAMPTZ)
LANGUAGE sql STABLE AS $$
    SELECT c.id, c.type, c.name, c.created_at
    FROM conversations c
    WHERE c.type = 'private'
      AND EXISTS (
          SELECT 1 FROM conversation_members cm
          WHERE cm.conversation_id = c.id AND cm.user_id = user_a AND cm.left_at IS NULL
      )
      AND EXISTS (
          SELECT 1 FROM conversation_members cm
          WHERE cm.conversation_id = c.id AND cm.user_id = user_b AND cm.left_at IS NULL
      )
    LIMIT 1;
$$;
