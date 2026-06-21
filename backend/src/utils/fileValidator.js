// Allowed MIME types and their size limits (in bytes)
const ALLOWED = {
    // Images
    'image/jpeg':                  { type: 'image',    maxBytes: 10  * 1024 * 1024 },
    'image/png':                   { type: 'image',    maxBytes: 10  * 1024 * 1024 },
    'image/gif':                   { type: 'image',    maxBytes: 10  * 1024 * 1024 },
    'image/webp':                  { type: 'image',    maxBytes: 10  * 1024 * 1024 },
    // Audio
    'audio/mpeg':                  { type: 'audio',    maxBytes: 25  * 1024 * 1024 },
    'audio/ogg':                   { type: 'audio',    maxBytes: 25  * 1024 * 1024 },
    'audio/wav':                   { type: 'audio',    maxBytes: 25  * 1024 * 1024 },
    'audio/webm':                  { type: 'audio',    maxBytes: 25  * 1024 * 1024 },
    // Video
    'video/mp4':                   { type: 'video',    maxBytes: 200 * 1024 * 1024 },
    'video/webm':                  { type: 'video',    maxBytes: 200 * 1024 * 1024 },
    'video/ogg':                   { type: 'video',    maxBytes: 200 * 1024 * 1024 },
    // Documents
    'application/pdf':             { type: 'document', maxBytes: 50  * 1024 * 1024 },
    'application/msword':          { type: 'document', maxBytes: 50  * 1024 * 1024 },
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
                                   { type: 'document', maxBytes: 50  * 1024 * 1024 },
    'application/vnd.ms-excel':    { type: 'document', maxBytes: 50  * 1024 * 1024 },
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
                                   { type: 'document', maxBytes: 50  * 1024 * 1024 },
    'text/plain':                  { type: 'document', maxBytes: 10  * 1024 * 1024 },
};

function validate(mimeType, fileSizeBytes) {
    const rule = ALLOWED[mimeType];
    if (!rule) return { ok: false, error: `File type not allowed: ${mimeType}` };
    if (fileSizeBytes > rule.maxBytes) {
        const mb = Math.round(rule.maxBytes / 1024 / 1024);
        return { ok: false, error: `File too large. Maximum size for ${rule.type} is ${mb} MB` };
    }
    return { ok: true, mediaType: rule.type };
}

// multer filter function — rejects disallowed types before they reach memory
function multerFilter(req, file, cb) {
    if (ALLOWED[file.mimetype]) {
        cb(null, true);
    } else {
        cb(new Error(`File type not allowed: ${file.mimetype}`), false);
    }
}

module.exports = { validate, multerFilter };
