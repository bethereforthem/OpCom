const supabase = require('../utils/supabase');

async function log(action, { userId = null, targetType = null, targetId = null, metadata = null, ipAddress = null } = {}) {
    await supabase.from('audit_logs').insert({
        user_id: userId,
        action,
        target_type: targetType,
        target_id: targetId,
        metadata,
        ip_address: ipAddress,
    });
}

module.exports = { log };
