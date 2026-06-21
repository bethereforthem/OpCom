const express = require('express');
const multer = require('multer');
const crypto = require('crypto');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const supabase = require('../utils/supabase');
const { requireAuth, requirePermission } = require('../middleware/auth');
const { uploadFile, presignedUrl, deleteFile } = require('../utils/minio');
const { validate, multerFilter } = require('../utils/fileValidator');
const audit = require('../services/auditLog');

const router = express.Router();

// Keep files in memory (max 200 MB enforced by multer, actual per-type limits in validator)
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 200 * 1024 * 1024 },
    fileFilter: multerFilter,
});

// ── POST /media/upload ─────────────────────────────────────────
// Upload a file and get back a media_id to use in a message
router.post('/upload', requireAuth, requirePermission('send_media'), upload.single('file'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No file provided' });

    const { originalname, mimetype, buffer, size } = req.file;

    // Validate type + size
    const validation = validate(mimetype, size);
    if (!validation.ok) return res.status(400).json({ error: validation.error });

    const { mediaType } = validation;
    const now = new Date();
    const year  = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const ext   = path.extname(originalname).toLowerCase() || '';
    const objectKey = `${mediaType}/${year}/${month}/${uuidv4()}${ext}`;

    // SHA-256 checksum for integrity
    const checksum = crypto.createHash('sha256').update(buffer).digest('hex');

    // Upload to MinIO
    try {
        await uploadFile({ buffer, objectKey, mimeType: mimetype, size });
    } catch (err) {
        console.error('MinIO upload error:', err);
        return res.status(500).json({ error: 'File upload failed' });
    }

    // Record in database
    const { data: mediaFile, error } = await supabase
        .from('media_files')
        .insert({
            uploader_id:     req.user.id,
            bucket:          process.env.MINIO_BUCKET || 'opcom-media',
            object_key:      objectKey,
            file_name:       originalname,
            mime_type:       mimetype,
            file_size_bytes: size,
            checksum_sha256: checksum,
            is_encrypted:    false, // MinIO server-side encryption set at bucket level
        })
        .select('id, file_name, mime_type, file_size_bytes, created_at')
        .single();

    if (error) {
        // Roll back: remove the just-uploaded file from MinIO
        await deleteFile(objectKey).catch(() => {});
        return res.status(500).json({ error: 'Failed to record media file' });
    }

    await audit.log('upload_media', {
        userId: req.user.id,
        targetType: 'media_file',
        targetId: mediaFile.id,
        metadata: { mime_type: mimetype, size_bytes: size },
        ipAddress: req.ip,
    });

    res.status(201).json({ media_id: mediaFile.id, file: mediaFile });
});

// ── GET /media/avatar/:userId ───────────────────────────────────
// Redirects to a fresh presigned URL for a user's current avatar.
// Intentionally NOT requireAuth: a profile picture is low-sensitivity
// (already discoverable by any authenticated user via /users/lookup), and
// leaving this open avoids having to plumb the bearer token through every
// image loader (NetworkImage / CachedNetworkImage) across the whole app.
// Actual message/document media stays behind requireAuth + membership
// checks below, unchanged.
router.get('/avatar/:userId', async (req, res) => {
    const { data: user } = await supabase
        .from('users')
        .select('avatar_object_key')
        .eq('id', req.params.userId)
        .single();

    if (!user?.avatar_object_key) return res.status(404).json({ error: 'No avatar set' });

    try {
        const url = await presignedUrl(user.avatar_object_key, 3600);
        res.redirect(url);
    } catch {
        res.status(500).json({ error: 'Failed to resolve avatar' });
    }
});

// ── GET /media/:id/url ─────────────────────────────────────────
// Get a short-lived presigned URL to download/view a media file
router.get('/:id/url', requireAuth, async (req, res) => {
    const { data: media, error } = await supabase
        .from('media_files')
        .select('id, object_key, mime_type, file_name')
        .eq('id', req.params.id)
        .single();

    if (error || !media) return res.status(404).json({ error: 'Media file not found' });

    // Verify the requester has access — they must share a conversation with the uploader
    // (checked via message that references this media_id)
    const { data: message } = await supabase
        .from('messages')
        .select('conversation_id')
        .eq('media_id', media.id)
        .limit(1)
        .single();

    if (message) {
        const { data: membership } = await supabase
            .from('conversation_members')
            .select('user_id')
            .eq('conversation_id', message.conversation_id)
            .eq('user_id', req.user.id)
            .is('left_at', null)
            .single();

        if (!membership) return res.status(403).json({ error: 'Access denied' });
    }

    try {
        const url = await presignedUrl(media.object_key, 3600);
        res.json({ url, expires_in: 3600, mime_type: media.mime_type, file_name: media.file_name });
    } catch {
        res.status(500).json({ error: 'Failed to generate download URL' });
    }
});

// ── DELETE /media/:id ──────────────────────────────────────────
// Only the uploader or an admin can delete a file
router.delete('/:id', requireAuth, async (req, res) => {
    const { data: media } = await supabase
        .from('media_files')
        .select('id, object_key, uploader_id')
        .eq('id', req.params.id)
        .single();

    if (!media) return res.status(404).json({ error: 'Media file not found' });

    const isUploader = media.uploader_id === req.user.id;
    const isAdmin    = req.permissions.has('delete_user'); // admins have broad delete rights

    if (!isUploader && !isAdmin) {
        return res.status(403).json({ error: 'Access denied' });
    }

    await deleteFile(media.object_key).catch(() => {});
    await supabase.from('media_files').delete().eq('id', media.id);

    await audit.log('delete_media', {
        userId: req.user.id,
        targetType: 'media_file',
        targetId: media.id,
        ipAddress: req.ip,
    });

    res.json({ message: 'File deleted' });
});

module.exports = router;
