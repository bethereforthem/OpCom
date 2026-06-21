# OpCom — Supabase Setup Guide

## Step-by-Step Instructions

### 1. Create a Supabase project

1. Go to https://supabase.com and sign in
2. Click **New Project**
3. Name it `opcom` (or `opcom-dev` for development)
4. Choose a strong database password — **save it somewhere safe**
5. Select the region closest to your organization
6. Click **Create new project** and wait ~2 minutes

---

### 2. Run the schema migration

1. In your Supabase dashboard, go to **Database → SQL Editor**
2. Click **New Query**
3. Open the file: `supabase/migrations/001_initial_schema.sql`
4. Paste the entire contents into the SQL editor
5. Click **Run** (or press Ctrl+Enter)
6. You should see: `Success. No rows returned`

---

### 3. Run the seed data

1. Still in **SQL Editor**, open a new query
2. Open the file: `supabase/seed/001_seed_roles_permissions.sql`
3. Paste and run it
4. This creates the 5 default roles and all permissions

---

### 4. Collect your API credentials

Go to **Settings → API** and copy:

| Variable | Where to find it |
|---|---|
| `SUPABASE_URL` | Project URL (e.g. `https://xxxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | `anon` `public` key |
| `SUPABASE_SERVICE_ROLE_KEY` | `service_role` key (**keep secret — server only**) |

Store these in a `.env` file (never commit it to git):

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
```

---

## Database Map

```
┌─────────────────────────────────────────────────────────────────┐
│  SECTION 1: ROLES & PERMISSIONS (RBAC)                         │
│  roles ──< role_permissions >── permissions                     │
└────────────────────────┬────────────────────────────────────────┘
                         │ role_id
┌────────────────────────▼────────────────────────────────────────┐
│  SECTION 2: USERS & AUTHENTICATION                              │
│  users ──< user_mfa                                             │
│  users ──< sessions ──> authorized_devices                      │
│  users ──< otp_codes                                            │
└────────────────────────┬────────────────────────────────────────┘
                         │ sender_id / user_id
┌────────────────────────▼────────────────────────────────────────┐
│  SECTION 3: MESSAGING                                           │
│  conversations ──< conversation_members >── users               │
│  conversations ──< messages ──> media_files                     │
│  messages      ──< message_status >── users                     │
└────────────────────────┬────────────────────────────────────────┘
                         │ uploader_id
┌────────────────────────▼────────────────────────────────────────┐
│  SECTION 4: MEDIA STORAGE                                       │
│  media_files  (MinIO bucket + object_key reference)             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  SECTION 5: SECURITY & MONITORING                               │
│  audit_logs  login_attempts  security_alerts                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  SECTION 6: SYSTEM SUPPORT                                      │
│  notifications  authorized_devices                              │
└─────────────────────────────────────────────────────────────────┘
```

## Tables Summary

| Table | Purpose |
|---|---|
| `roles` | System roles: admin, supervisor, officer, analyst, it_support |
| `permissions` | Granular actions (send_message, view_logs, manage_users…) |
| `role_permissions` | Maps roles to the permissions they hold |
| `users` | User accounts; login via username, email, or staff_id |
| `user_mfa` | MFA method (email OTP or TOTP) and secret per user |
| `sessions` | Active JWT sessions with expiry tracking |
| `otp_codes` | Short-lived OTP codes for email MFA and password reset |
| `conversations` | Private (2-user) or group conversations |
| `conversation_members` | Who is in each conversation and their group role |
| `messages` | All messages with type, content, and soft-delete |
| `message_status` | Per-recipient delivered/read timestamps |
| `media_files` | MinIO file references (bucket + object_key + checksum) |
| `audit_logs` | Immutable append-only log of every significant action |
| `login_attempts` | Every login try — success and failure — with IP |
| `security_alerts` | Raised alerts with severity, type, and resolution tracking |
| `notifications` | In-app notifications per user |
| `authorized_devices` | Admin-approved devices; unapproved devices cannot connect |

## Built-in Automatic Behaviors

| Trigger | What it does |
|---|---|
| `trg_users_updated_at` | Sets `users.updated_at` on every update |
| `trg_conversations_updated_at` | Same for conversations |
| `trg_messages_updated_at` | Same for messages |
| `trg_user_mfa_updated_at` | Same for MFA config |
| `trg_login_lockout` | Locks account after 5 failed login attempts |

## Row Level Security

RLS is enabled on all sensitive tables. The **service role key** (used by your Node.js backend) bypasses RLS. The **anon/authenticated keys** (used by clients) are restricted:

- Users see only their own row in `users`, `sessions`, `user_mfa`
- Users see only conversations they are a member of
- Users see only messages inside their conversations
- Only admins can read `audit_logs`

## Next Steps (Development Phases)

- [ ] **Phase 1** — Node.js/Express backend: auth endpoints (register, login, MFA verify)
- [ ] **Phase 2** — WebSocket server for real-time messaging
- [ ] **Phase 3** — MinIO integration for media uploads
- [ ] **Phase 4** — WebRTC signaling server for voice/video calls
- [ ] **Phase 5** — React web client
- [ ] **Phase 6** — Flutter mobile client
- [ ] **Phase 7** — Admin dashboard (logs, device approval, user management)
