# Winga App — Supabase Backend

## Project
- **URL:** https://kevdbsyiqelksxvmuped.supabase.co
- **Project Ref:** kevdbsyiqelksxvmuped

## Setup Steps

### 1. Run Migrations (in order)
Go to Supabase Dashboard → SQL Editor and run each file:
```
migrations/001_initial_schema.sql   ← Tables, tiers, indexes
migrations/002_rls_policies.sql     ← Row Level Security
migrations/003_triggers_functions.sql ← Triggers, RPCs
migrations/004_seed_admin.sql       ← Default admin user
```

### 2. Deploy Edge Functions
```bash
supabase login
supabase link --project-ref kevdbsyiqelksxvmuped
supabase functions deploy register-winga
supabase functions deploy initiate-payment
supabase functions deploy confirm-payment
supabase functions deploy verify-winga
supabase functions deploy assign-badge
supabase functions deploy send-notification
```

### 3. Set Edge Function Secrets
```bash
supabase secrets set FCM_SERVER_KEY=your_firebase_server_key
supabase secrets set SELCOM_API_KEY=your_selcom_key        # for production payments
supabase secrets set SELCOM_VENDOR=your_vendor_id
```

## Verification Flow

```
Winga registers (register-winga function)
       ↓
Winga uploads documents (winga_documents table)
       ↓
Winga pays monthly fee (initiate-payment → confirm-payment)
  Starter: TZS 5,000/month
  Mid:     TZS 15,000/month
  Verified: TZS 30,000/month
       ↓
Status → under_review (admin notified)
       ↓
Admin reviews in admin panel
       ↓
Admin verifies (verify-winga function)  OR  rejects
       ↓
Badge assigned: Starter 🥉 | Mid 🥈 | Verified 🥇
       ↓
Winga goes Active — can receive requests
       ↓
Badge auto-expires after 30 days → must renew payment
```

## Badge Tiers
| Badge | Fee | Color | Perks |
|---|---|---|---|
| Starter 🥉 | TZS 5,000/mo | Bronze | Basic listing, verified tick |
| Mid 🥈 | TZS 15,000/mo | Silver | Priority listing, analytics |
| Verified 🥇 | TZS 30,000/mo | Gold | Top placement, featured, marketing |

## Admin Credentials (change after first login)
- **Email:** admin@winga.co.tz
- **Password:** Admin@Winga2026

## RPC Functions (call from admin panel)
```sql
-- Verify a winga
SELECT admin_verify_winga('winga-uuid', 'Verified', 'All docs confirmed');

-- Reject a winga
SELECT admin_reject_winga('winga-uuid', 'National ID unclear');

-- Change badge
SELECT admin_assign_badge('winga-uuid', 'Mid');

-- Expire subscriptions (run daily via cron)
SELECT expire_subscriptions();
```
