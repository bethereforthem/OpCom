-- =============================================================
-- OpCom — Migration 010: profile fields + user preferences
-- Run in Supabase SQL Editor, after 001-009
-- =============================================================

-- Profile
ALTER TABLE users ADD COLUMN bio TEXT;
ALTER TABLE users ADD COLUMN status_message TEXT;

-- Avatar — `avatar_url` (already existed, unused until now) becomes a stable
-- "/media/avatar/{userId}" path once set; `avatar_object_key` is the actual
-- MinIO key it currently points to and is never sent to clients. Keeping
-- avatar_url as a resolve-on-request path (not a baked-in presigned URL)
-- means it never expires and every existing place that already returns
-- avatar_url (conversations, messages, calls, search, sockets) keeps working
-- completely unchanged.
ALTER TABLE users ADD COLUMN avatar_object_key TEXT;

-- Appearance — only 'dark' actually renders today; 'light'/'system' persist
-- correctly but are a visual no-op until the app gains a real light theme.
ALTER TABLE users ADD COLUMN theme_preference TEXT NOT NULL DEFAULT 'dark'
    CHECK (theme_preference IN ('dark', 'light', 'system'));

-- Notifications (sound/vibrate on incoming calls & messages while foregrounded —
-- this app has no push-notification infra, so there's nothing else to toggle)
ALTER TABLE users ADD COLUMN notif_sound_enabled BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN notif_vibrate_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- Privacy — defaults match current always-on behavior exactly, so existing
-- users see no change until they opt out.
ALTER TABLE users ADD COLUMN privacy_read_receipts BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN privacy_show_typing BOOLEAN NOT NULL DEFAULT TRUE;

-- Chat preferences — default matches current always-manual media loading.
ALTER TABLE users ADD COLUMN chat_auto_download_media BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN chat_message_text_scale TEXT NOT NULL DEFAULT 'medium'
    CHECK (chat_message_text_scale IN ('small', 'medium', 'large'));
