-- =============================================================
-- OpCom: Secure Internal Communication System
-- Supabase / PostgreSQL Schema — Migration 001
-- =============================================================
-- Run this entire file in the Supabase SQL Editor
-- (Database → SQL Editor → New Query → Paste → Run)
-- =============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================
-- SECTION 1: ROLES AND PERMISSIONS (RBAC)
-- Must be created first — users depend on roles
-- =============================================================

CREATE TABLE roles (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,          -- 'admin', 'supervisor', 'officer', 'analyst', etc.
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE permissions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,          -- 'send_message', 'view_logs', 'manage_users', etc.
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE role_permissions (
    role_id       UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- =============================================================
-- SECTION 2: USERS AND AUTHENTICATION
-- =============================================================

CREATE TABLE users (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username         TEXT NOT NULL UNIQUE,
    email            TEXT UNIQUE,
    staff_id         TEXT UNIQUE,              -- officer/staff badge number for private-network login
    password_hash    TEXT NOT NULL,            -- bcrypt hash, never plaintext
    full_name        TEXT NOT NULL,
    role_id          UUID REFERENCES roles(id) ON DELETE SET NULL,
    avatar_url       TEXT,                     -- MinIO path
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    is_locked        BOOLEAN NOT NULL DEFAULT FALSE,
    failed_attempts  INT NOT NULL DEFAULT 0,
    last_login_at    TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- MFA configuration per user
CREATE TABLE user_mfa (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    method          TEXT NOT NULL CHECK (method IN ('email_otp', 'totp')),  -- TOTP = Google Authenticator
    totp_secret     TEXT,                      -- encrypted TOTP seed (only for 'totp' method)
    is_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
    backup_codes    TEXT[],                    -- hashed backup codes
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Active login sessions / JWT tracking
CREATE TABLE sessions (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id     UUID,                        -- references authorized_devices.id
    jwt_jti       TEXT NOT NULL UNIQUE,        -- JWT ID claim for revocation
    ip_address    INET,
    user_agent    TEXT,
    expires_at    TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Temporary OTP codes for email-based MFA
CREATE TABLE otp_codes (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash   TEXT NOT NULL,                 -- bcrypt hash of the 6-digit code
    purpose     TEXT NOT NULL DEFAULT 'mfa',   -- 'mfa', 'password_reset'
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- SECTION 3: MESSAGING
-- =============================================================

-- A conversation is either private (2 users) or a group
CREATE TABLE conversations (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type         TEXT NOT NULL CHECK (type IN ('private', 'group')),
    name         TEXT,                         -- only for group conversations
    avatar_url   TEXT,                         -- group avatar on MinIO
    created_by   UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Members of a conversation and their roles within it
CREATE TABLE conversation_members (
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role            TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at         TIMESTAMPTZ,               -- NULL means still active member
    PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    type            TEXT NOT NULL DEFAULT 'text'
                        CHECK (type IN ('text', 'image', 'audio', 'video', 'document', 'system')),
    content         TEXT,                      -- text body or system event description
    media_id        UUID,                      -- references media_files.id when type != 'text'
    reply_to_id     UUID REFERENCES messages(id) ON DELETE SET NULL,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Per-recipient delivery and read tracking
CREATE TABLE message_status (
    message_id   UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivered_at TIMESTAMPTZ,
    read_at      TIMESTAMPTZ,
    PRIMARY KEY (message_id, user_id)
);

-- =============================================================
-- SECTION 4: MEDIA STORAGE
-- Files live on MinIO; this table stores the metadata reference
-- =============================================================

CREATE TABLE media_files (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    uploader_id    UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    bucket         TEXT NOT NULL,              -- MinIO bucket name
    object_key     TEXT NOT NULL,              -- full path inside the bucket
    file_name      TEXT NOT NULL,
    mime_type      TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    checksum_sha256 TEXT,                      -- integrity verification
    is_encrypted   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add FK from messages to media_files (after both tables exist)
ALTER TABLE messages
    ADD CONSTRAINT fk_messages_media
    FOREIGN KEY (media_id) REFERENCES media_files(id) ON DELETE SET NULL;

-- =============================================================
-- SECTION 5: SECURITY AND MONITORING
-- =============================================================

-- Immutable audit log — INSERT only, never UPDATE or DELETE
CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
    action      TEXT NOT NULL,                 -- 'login', 'logout', 'send_message', 'delete_user', etc.
    target_type TEXT,                          -- 'user', 'message', 'conversation', etc.
    target_id   UUID,
    metadata    JSONB,                         -- extra context (IP, device, old/new values)
    ip_address  INET,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Login attempt log (both successes and failures)
CREATE TABLE login_attempts (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    identifier   TEXT NOT NULL,                -- username, email, or staff_id that was tried
    user_id      UUID REFERENCES users(id) ON DELETE SET NULL,
    success      BOOLEAN NOT NULL,
    failure_reason TEXT,                       -- 'bad_password', 'mfa_failed', 'account_locked', etc.
    ip_address   INET,
    user_agent   TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Security alerts raised by monitoring rules
CREATE TABLE security_alerts (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    severity     TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    type         TEXT NOT NULL,                -- 'brute_force', 'unauthorized_device', 'unusual_access', etc.
    user_id      UUID REFERENCES users(id) ON DELETE SET NULL,
    description  TEXT NOT NULL,
    metadata     JSONB,
    resolved_at  TIMESTAMPTZ,
    resolved_by  UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- SECTION 6: SYSTEM SUPPORT
-- =============================================================

-- In-app notifications
CREATE TABLE notifications (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        TEXT NOT NULL,                 -- 'new_message', 'mfa_alert', 'account_locked', etc.
    title       TEXT NOT NULL,
    body        TEXT,
    metadata    JSONB,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    read_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Only administrator-approved devices may connect
CREATE TABLE authorized_devices (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_name    TEXT NOT NULL,
    device_fingerprint TEXT NOT NULL,          -- e.g., hash of hardware identifiers
    platform       TEXT,                       -- 'web', 'android', 'ios'
    approved_by    UUID REFERENCES users(id) ON DELETE SET NULL,
    approved_at    TIMESTAMPTZ,
    is_active      BOOLEAN NOT NULL DEFAULT FALSE,
    revoked_at     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add FK from sessions to authorized_devices (after table exists)
ALTER TABLE sessions
    ADD CONSTRAINT fk_sessions_device
    FOREIGN KEY (device_id) REFERENCES authorized_devices(id) ON DELETE SET NULL;

-- =============================================================
-- INDEXES
-- =============================================================

-- Users
CREATE INDEX idx_users_email       ON users(email);
CREATE INDEX idx_users_staff_id    ON users(staff_id);
CREATE INDEX idx_users_role_id     ON users(role_id);

-- Sessions
CREATE INDEX idx_sessions_user_id  ON sessions(user_id);
CREATE INDEX idx_sessions_expires  ON sessions(expires_at);

-- OTP
CREATE INDEX idx_otp_user_id       ON otp_codes(user_id);
CREATE INDEX idx_otp_expires       ON otp_codes(expires_at);

-- Messages
CREATE INDEX idx_messages_conv_id  ON messages(conversation_id);
CREATE INDEX idx_messages_sender   ON messages(sender_id);
CREATE INDEX idx_messages_created  ON messages(created_at DESC);

-- Conversation members
CREATE INDEX idx_conv_members_user ON conversation_members(user_id);

-- Audit logs
CREATE INDEX idx_audit_user_id     ON audit_logs(user_id);
CREATE INDEX idx_audit_action      ON audit_logs(action);
CREATE INDEX idx_audit_created     ON audit_logs(created_at DESC);

-- Login attempts
CREATE INDEX idx_login_identifier  ON login_attempts(identifier);
CREATE INDEX idx_login_ip          ON login_attempts(ip_address);
CREATE INDEX idx_login_created     ON login_attempts(created_at DESC);

-- Notifications
CREATE INDEX idx_notif_user_unread ON notifications(user_id) WHERE is_read = FALSE;

-- Authorized devices
CREATE INDEX idx_devices_user_id   ON authorized_devices(user_id);

-- =============================================================
-- UPDATED_AT TRIGGER
-- Automatically update updated_at on every row change
-- =============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_conversations_updated_at
    BEFORE UPDATE ON conversations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_messages_updated_at
    BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_mfa_updated_at
    BEFORE UPDATE ON user_mfa
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================
-- ACCOUNT LOCKOUT TRIGGER
-- Lock account after 5 consecutive failed login attempts
-- =============================================================

CREATE OR REPLACE FUNCTION check_account_lockout()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.success = FALSE THEN
        UPDATE users
        SET
            failed_attempts = failed_attempts + 1,
            is_locked = CASE WHEN failed_attempts + 1 >= 5 THEN TRUE ELSE is_locked END
        WHERE id = NEW.user_id;
    ELSE
        UPDATE users
        SET failed_attempts = 0
        WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_login_lockout
    AFTER INSERT ON login_attempts
    FOR EACH ROW EXECUTE FUNCTION check_account_lockout();

-- =============================================================
-- ROW LEVEL SECURITY (RLS)
-- Only enable after your backend service role is configured.
-- Service role (server-side) bypasses RLS.
-- Anon / authenticated roles are restricted as below.
-- =============================================================

ALTER TABLE users                ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_mfa             ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions             ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations        ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages             ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_status       ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications        ENABLE ROW LEVEL SECURITY;
ALTER TABLE authorized_devices   ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs           ENABLE ROW LEVEL SECURITY;

-- Users can only read their own row
CREATE POLICY "users_select_own" ON users
    FOR SELECT USING (auth.uid() = id);

-- Users can only read their own MFA config
CREATE POLICY "mfa_select_own" ON user_mfa
    FOR SELECT USING (auth.uid() = user_id);

-- Users can only read their own sessions
CREATE POLICY "sessions_select_own" ON sessions
    FOR SELECT USING (auth.uid() = user_id);

-- Users can only read conversations they are a member of
CREATE POLICY "conv_select_member" ON conversations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversation_members cm
            WHERE cm.conversation_id = id
              AND cm.user_id = auth.uid()
              AND cm.left_at IS NULL
        )
    );

-- Users can only read messages in their conversations
CREATE POLICY "msg_select_member" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversation_members cm
            WHERE cm.conversation_id = messages.conversation_id
              AND cm.user_id = auth.uid()
              AND cm.left_at IS NULL
        )
    );

-- Users can only see their own notifications
CREATE POLICY "notif_select_own" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Audit logs: only admins can read (enforced at app layer too)
CREATE POLICY "audit_admin_only" ON audit_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE u.id = auth.uid()
              AND r.name = 'admin'
        )
    );
