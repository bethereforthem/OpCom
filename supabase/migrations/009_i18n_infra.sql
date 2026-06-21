-- =============================================================
-- OpCom — Migration 009: i18n infrastructure
-- (English / Kinyarwanda / French)
-- Run in Supabase SQL Editor, after 001-008
-- =============================================================

ALTER TABLE users ADD COLUMN locale TEXT NOT NULL DEFAULT 'en' CHECK (locale IN ('en', 'rw', 'fr'));

-- Structured system-message data so each viewer renders it in their own
-- language; `content` (English) stays as a fallback for rows created
-- before this column existed, or for any future unrecognized event.
ALTER TABLE messages ADD COLUMN system_event  TEXT;
ALTER TABLE messages ADD COLUMN system_params JSONB;
