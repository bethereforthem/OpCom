// Allowed MIME types grouped by category with per-type size limits (bytes).
// Unknown/unlisted MIME types are accepted as 'document' up to 100 MB so
// users can share any file extension — PDFs, spreadsheets, code archives, etc.
const ALLOWED = {
  // ── Images ───────────────────────────────────────────────────
  'image/jpeg':  { type: 'image', maxBytes: 10 * 1024 * 1024 },
  'image/png':   { type: 'image', maxBytes: 10 * 1024 * 1024 },
  'image/gif':   { type: 'image', maxBytes: 10 * 1024 * 1024 },
  'image/webp':  { type: 'image', maxBytes: 10 * 1024 * 1024 },
  'image/svg+xml': { type: 'image', maxBytes: 10 * 1024 * 1024 },
  'image/bmp':   { type: 'image', maxBytes: 10 * 1024 * 1024 },
  'image/tiff':  { type: 'image', maxBytes: 10 * 1024 * 1024 },
  'image/heic':  { type: 'image', maxBytes: 10 * 1024 * 1024 },
  'image/heif':  { type: 'image', maxBytes: 10 * 1024 * 1024 },

  // ── Audio ────────────────────────────────────────────────────
  'audio/mpeg':  { type: 'audio', maxBytes: 50 * 1024 * 1024 },
  'audio/ogg':   { type: 'audio', maxBytes: 50 * 1024 * 1024 },
  'audio/wav':   { type: 'audio', maxBytes: 50 * 1024 * 1024 },
  'audio/webm':  { type: 'audio', maxBytes: 50 * 1024 * 1024 },
  'audio/mp4':   { type: 'audio', maxBytes: 50 * 1024 * 1024 }, // M4A voice notes (iOS/Android recorder)
  'audio/x-m4a': { type: 'audio', maxBytes: 50 * 1024 * 1024 },
  'audio/aac':   { type: 'audio', maxBytes: 50 * 1024 * 1024 },
  'audio/flac':  { type: 'audio', maxBytes: 50 * 1024 * 1024 },
  'audio/x-wav': { type: 'audio', maxBytes: 50 * 1024 * 1024 },
  'audio/3gpp':  { type: 'audio', maxBytes: 50 * 1024 * 1024 },

  // ── Video ────────────────────────────────────────────────────
  'video/mp4':   { type: 'video', maxBytes: 200 * 1024 * 1024 },
  'video/webm':  { type: 'video', maxBytes: 200 * 1024 * 1024 },
  'video/ogg':   { type: 'video', maxBytes: 200 * 1024 * 1024 },
  'video/quicktime': { type: 'video', maxBytes: 200 * 1024 * 1024 },
  'video/x-msvideo': { type: 'video', maxBytes: 200 * 1024 * 1024 }, // AVI
  'video/x-matroska': { type: 'video', maxBytes: 200 * 1024 * 1024 }, // MKV
  'video/3gpp':  { type: 'video', maxBytes: 200 * 1024 * 1024 },

  // ── Documents & office ───────────────────────────────────────
  'application/pdf':     { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/msword':  { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
                         { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/vnd.ms-excel': { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
                         { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/vnd.ms-powerpoint': { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
                         { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/vnd.oasis.opendocument.text':         { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/vnd.oasis.opendocument.spreadsheet':  { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'application/vnd.oasis.opendocument.presentation': { type: 'document', maxBytes: 100 * 1024 * 1024 },
  'text/plain':          { type: 'document', maxBytes: 20  * 1024 * 1024 },
  'text/csv':            { type: 'document', maxBytes: 50  * 1024 * 1024 },
  'text/html':           { type: 'document', maxBytes: 20  * 1024 * 1024 },
  'text/xml':            { type: 'document', maxBytes: 20  * 1024 * 1024 },
  'application/xml':     { type: 'document', maxBytes: 20  * 1024 * 1024 },
  'application/json':    { type: 'document', maxBytes: 10  * 1024 * 1024 },

  // ── Archives ─────────────────────────────────────────────────
  'application/zip':                  { type: 'document', maxBytes: 200 * 1024 * 1024 },
  'application/x-zip-compressed':     { type: 'document', maxBytes: 200 * 1024 * 1024 },
  'application/x-rar-compressed':     { type: 'document', maxBytes: 200 * 1024 * 1024 },
  'application/vnd.rar':              { type: 'document', maxBytes: 200 * 1024 * 1024 },
  'application/x-7z-compressed':      { type: 'document', maxBytes: 200 * 1024 * 1024 },
  'application/x-tar':                { type: 'document', maxBytes: 200 * 1024 * 1024 },
  'application/gzip':                 { type: 'document', maxBytes: 200 * 1024 * 1024 },
  'application/x-bzip2':              { type: 'document', maxBytes: 200 * 1024 * 1024 },

  // ── Code / config ────────────────────────────────────────────
  'application/javascript':    { type: 'document', maxBytes: 10 * 1024 * 1024 },
  'text/javascript':           { type: 'document', maxBytes: 10 * 1024 * 1024 },
  'text/x-python':             { type: 'document', maxBytes: 10 * 1024 * 1024 },
  'text/x-java-source':        { type: 'document', maxBytes: 10 * 1024 * 1024 },
  'text/markdown':             { type: 'document', maxBytes: 10 * 1024 * 1024 },
  'text/x-yaml':               { type: 'document', maxBytes: 10 * 1024 * 1024 },

  // ── APK / installers ─────────────────────────────────────────
  'application/vnd.android.package-archive': { type: 'document', maxBytes: 200 * 1024 * 1024 },
};

// Maximum catch-all size for types not listed above (100 MB)
const FALLBACK_MAX_BYTES = 100 * 1024 * 1024;

function validate(mimeType, fileSizeBytes) {
    const rule = ALLOWED[mimeType];
    if (rule) {
        if (fileSizeBytes > rule.maxBytes) {
            const mb = Math.round(rule.maxBytes / 1024 / 1024);
            return { ok: false, error: `File too large. Maximum size for ${rule.type} is ${mb} MB` };
        }
        return { ok: true, mediaType: rule.type };
    }

    // Unknown MIME type — accept as generic document up to FALLBACK_MAX_BYTES
    if (fileSizeBytes > FALLBACK_MAX_BYTES) {
        return { ok: false, error: `File too large. Maximum file size is ${Math.round(FALLBACK_MAX_BYTES / 1024 / 1024)} MB` };
    }
    return { ok: true, mediaType: 'document' };
}

// multer filter — accept everything; size/type enforcement happens in validate()
function multerFilter(req, file, cb) {
    cb(null, true);
}

module.exports = { validate, multerFilter };
