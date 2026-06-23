-- Ensure officer and supervisor roles have the full set of permissions
-- needed to use the mobile app (messaging, media, groups).
-- ON CONFLICT DO NOTHING makes this safe to run multiple times.

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE
    (
        r.name = 'officer'
        AND p.name IN (
            'send_message',
            'send_media',
            'delete_own_message',
            'create_group'
        )
    )
    OR
    (
        r.name = 'supervisor'
        AND p.name IN (
            'send_message',
            'send_media',
            'delete_own_message',
            'create_group',
            'manage_group',
            'view_users',
            'view_audit_logs'
        )
    )
ON CONFLICT DO NOTHING;
