// One-time bootstrap: create the very first account(s).
// /auth/register requires an existing admin token, so this script is the
// only way to seed users once roles/permissions have been loaded.
//
// Usage:
//   node scripts/createAdmin.js --username admin --password "Str0ngP@ss" --full_name "David Kayigamba" --email admin@opcom.local [--role admin]
//
// --role defaults to "admin"; valid: admin, supervisor, officer, analyst, it_support
// Run from the backend/ directory so .env is picked up.

require('dotenv').config();
const bcrypt = require('bcryptjs');
const supabase = require('../src/utils/supabase');

const ROLE_IDS = {
    admin:        '00000000-0000-0000-0000-000000000001',
    supervisor:   '00000000-0000-0000-0000-000000000002',
    officer:      '00000000-0000-0000-0000-000000000003',
    analyst:      '00000000-0000-0000-0000-000000000004',
    it_support:   '00000000-0000-0000-0000-000000000005',
};

function parseArgs(argv) {
    const out = {};
    for (let i = 0; i < argv.length; i += 2) {
        const key = argv[i]?.replace(/^--/, '');
        out[key] = argv[i + 1];
    }
    return out;
}

async function main() {
    const args = parseArgs(process.argv.slice(2));
    const { username, password, full_name, email, staff_id, role = 'admin' } = args;

    if (!username || !password || !full_name) {
        console.error('Required: --username <u> --password <p> --full_name "<name>" [--email <e>] [--staff_id <id>] [--role <role>]');
        process.exit(1);
    }

    const role_id = ROLE_IDS[role];
    if (!role_id) {
        console.error(`Unknown role "${role}". Valid roles: ${Object.keys(ROLE_IDS).join(', ')}`);
        process.exit(1);
    }

    const bcryptRounds = parseInt(process.env.BCRYPT_ROUNDS, 10) || 12;
    const password_hash = await bcrypt.hash(password, bcryptRounds);

    const { data, error } = await supabase
        .from('users')
        .insert({
            username,
            email: email || null,
            staff_id: staff_id || null,
            password_hash,
            full_name,
            role_id,
        })
        .select('id, username, full_name, role_id')
        .single();

    if (error) {
        console.error('Failed to create account:', error.message);
        process.exit(1);
    }

    console.log(`Account created (role: ${role}):`, data);
    process.exit(0);
}

main();
