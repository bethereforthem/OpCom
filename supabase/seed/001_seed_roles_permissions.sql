-- =============================================================
-- OpCom — Seed Data
-- Run AFTER 001_initial_schema.sql
-- =============================================================

-- -----------------------------------------------------------
-- ROLES
-- -----------------------------------------------------------
INSERT INTO roles (id, name, description) VALUES
    ('00000000-0000-0000-0000-000000000001', 'admin',        'Full system control — manage users, view all logs, configure system'),
    ('00000000-0000-0000-0000-000000000002', 'supervisor',   'Oversee officers, view team activity, manage group conversations'),
    ('00000000-0000-0000-0000-000000000003', 'officer',      'Standard field officer — send/receive messages and media'),
    ('00000000-0000-0000-0000-000000000004', 'analyst',      'Read access to logs and reports; no messaging'),
    ('00000000-0000-0000-0000-000000000005', 'it_support',   'View logs and user activity; assist users; cannot modify records');

-- -----------------------------------------------------------
-- PERMISSIONS
-- -----------------------------------------------------------
INSERT INTO permissions (id, name, description) VALUES
    -- Messaging
    ('10000000-0000-0000-0000-000000000001', 'send_message',          'Send text messages'),
    ('10000000-0000-0000-0000-000000000002', 'send_media',            'Send images, audio, video, documents'),
    ('10000000-0000-0000-0000-000000000003', 'delete_own_message',    'Delete own messages'),
    ('10000000-0000-0000-0000-000000000004', 'create_group',          'Create group conversations'),
    ('10000000-0000-0000-0000-000000000005', 'manage_group',          'Add/remove members from groups'),
    -- User management
    ('10000000-0000-0000-0000-000000000010', 'view_users',            'View user list and profiles'),
    ('10000000-0000-0000-0000-000000000011', 'create_user',           'Create new user accounts'),
    ('10000000-0000-0000-0000-000000000012', 'edit_user',             'Edit user accounts'),
    ('10000000-0000-0000-0000-000000000013', 'deactivate_user',       'Deactivate or lock user accounts'),
    ('10000000-0000-0000-0000-000000000014', 'delete_user',           'Permanently delete user accounts'),
    -- Device management
    ('10000000-0000-0000-0000-000000000020', 'approve_device',        'Approve new devices for users'),
    ('10000000-0000-0000-0000-000000000021', 'revoke_device',         'Revoke device access'),
    -- Logs and monitoring
    ('10000000-0000-0000-0000-000000000030', 'view_audit_logs',       'Read audit log entries'),
    ('10000000-0000-0000-0000-000000000031', 'view_security_alerts',  'View security alerts'),
    ('10000000-0000-0000-0000-000000000032', 'resolve_security_alert','Mark security alerts as resolved'),
    -- System configuration
    ('10000000-0000-0000-0000-000000000040', 'manage_roles',          'Create and edit roles and permissions'),
    ('10000000-0000-0000-0000-000000000041', 'view_system_stats',     'View system health and statistics');

-- -----------------------------------------------------------
-- ROLE → PERMISSION MAPPING
-- -----------------------------------------------------------

-- Admin: everything
INSERT INTO role_permissions (role_id, permission_id)
SELECT '00000000-0000-0000-0000-000000000001', id FROM permissions;

-- Supervisor: messaging + group management + view users + view logs
INSERT INTO role_permissions (role_id, permission_id) VALUES
    ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002'),
    ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003'),
    ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000004'),
    ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000005'),
    ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000010'),
    ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000030');

-- Officer: basic messaging only
INSERT INTO role_permissions (role_id, permission_id) VALUES
    ('00000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002'),
    ('00000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003');

-- Analyst: read logs and alerts only
INSERT INTO role_permissions (role_id, permission_id) VALUES
    ('00000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000030'),
    ('00000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000031'),
    ('00000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000041');

-- IT Support: view users + view logs + view alerts
INSERT INTO role_permissions (role_id, permission_id) VALUES
    ('00000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000010'),
    ('00000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000030'),
    ('00000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000031'),
    ('00000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000041');
