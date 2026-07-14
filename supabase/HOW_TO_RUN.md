# 🚀 Winga App — Supabase Setup Guide

## Project Details
| Item | Value |
|---|---|
| Project URL | https://kevdbsyiqelksxvmuped.supabase.co |
| Project Ref | kevdbsyiqelksxvmuped |
| Admin Email | admin@winga.co.tz |
| Admin Password | Admin@Winga2026 |

---

## STEP 1 — Run Migrations (SQL Editor)

Go to: **https://supabase.com/dashboard/project/kevdbsyiqelksxvmuped/sql/new**

Run each file **in order** — copy/paste and click Run:

| # | File | What it creates |
|---|---|---|
| 1 | `migrations/001_initial_schema.sql` | All tables: users, wingas, requests, transactions, reviews, notifications, verification_tiers, verification_payments, winga_documents, admin_audit_log |
| 2 | `migrations/002_rls_policies.sql` | Row Level Security — customers see own data, wingas see own, admins see all |
| 3 | `migrations/003_triggers_functions.sql` | Auto Winga ID (WNGA10001), rating recalculation, admin_verify_winga(), admin_assign_badge(), confirm_verification_payment() |
| 4 | `migrations/004_seed_admin.sql` | Default Super Admin user |
| 5 | `migrations/005_admin_views.sql` | Dashboard views: v_dashboard_stats, v_pending_verifications, v_earnings_summary, v_winga_leaderboard, get_dashboard_stats() RPC |
| 6 | `migrations/006_storage_buckets.sql` | Storage: avatars (public), documents (private), app-assets |

---

## STEP 2 — Enable Phone Auth (OTP)

Go to: **Authentication → Providers → Phone**

1. Enable Phone provider ✅
2. For testing use **Twilio** or enable **"Allow unconfirmed phone numbers"**
3. Save

---

## STEP 3 — Deploy Edge Functions

Install Supabase CLI first:
```bash
# Windows (PowerShell)
winget install Supabase.CLI

# Or with npm
npm install -g supabase
```

Then deploy:
```bash
cd Winga-App

# Login
supabase login

# Link to your project
supabase link --project-ref kevdbsyiqelksxvmuped

# Deploy all functions
supabase functions deploy register-winga
supabase functions deploy initiate-payment
supabase functions deploy confirm-payment
supabase functions deploy verify-winga
supabase functions deploy assign-badge
supabase functions deploy send-notification
```

---

## STEP 4 — Set Edge Function Secrets

```bash
# Firebase (for push notifications — optional for now)
supabase secrets set FCM_SERVER_KEY=your_firebase_server_key

# For production mobile payments (Selcom/Azampesa — optional for now)
supabase secrets set SELCOM_API_KEY=your_selcom_key
supabase secrets set SELCOM_VENDOR=your_vendor_id
```

---

## STEP 5 — Test the Setup

In SQL Editor, run these to verify:

```sql
-- Check tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' ORDER BY table_name;

-- Check verification tiers seeded
SELECT * FROM public.verification_tiers;

-- Check admin user created
SELECT id, phone, email, name, user_type FROM public.users;

-- Check dashboard stats work
SELECT get_dashboard_stats();
```

---

## Edge Functions Reference

| Function | URL | Called By |
|---|---|---|
| `register-winga` | `/functions/v1/register-winga` | Winga registration form |
| `initiate-payment` | `/functions/v1/initiate-payment` | Winga pays verification fee |
| `confirm-payment` | `/functions/v1/confirm-payment` | Payment provider webhook |
| `verify-winga` | `/functions/v1/verify-winga` | Admin verifies Winga |
| `assign-badge` | `/functions/v1/assign-badge` | Admin assigns badge tier |
| `send-notification` | `/functions/v1/send-notification` | Any event needing push |

---

## Verification Flow

```
1. Winga fills registration form
         ↓
2. register-winga (Edge Function)
   → Creates user + winga record
   → Status: unverified
         ↓
3. Winga uploads documents (to storage/documents bucket)
   → Status: documents_submitted
         ↓
4. Winga selects tier and pays:
   - Starter  🥉 → TZS 5,000/month
   - Mid      🥈 → TZS 15,000/month
   - Verified 🥇 → TZS 30,000/month
         ↓
5. initiate-payment → confirm-payment
   → Status: under_review
   → Admin gets notification
         ↓
6. Admin reviews in Admin Panel
   → Opens Wingas page → Clicks "Verify" button
   → Selects tier → Adds notes → Confirms
         ↓
7. verify-winga (Edge Function)
   → Status: verified
   → Badge assigned (Starter/Mid/Verified)
   → Winga gets notified
   → Badge expires in 30 days → must renew
         ↓
8. Winga is Active → can receive requests ✅
```

---

## Admin Panel SQL Shortcuts

```sql
-- Verify a Winga manually
SELECT admin_verify_winga(
  'winga-uuid-here',
  'Verified',  -- or 'Mid' or 'Starter'
  'All documents verified and confirmed'
);

-- Reject a Winga
SELECT admin_reject_winga(
  'winga-uuid-here',
  'National ID photo is unclear. Please resubmit.'
);

-- Change badge
SELECT admin_assign_badge(
  'winga-uuid-here',
  'Mid'  -- upgrade or downgrade
);

-- Expire old subscriptions (run daily)
SELECT expire_subscriptions();

-- View pending verifications
SELECT * FROM v_pending_verifications;

-- Dashboard stats
SELECT get_dashboard_stats();
```

---

## Storage Buckets

| Bucket | Access | Used For |
|---|---|---|
| `avatars` | Public | Profile photos |
| `documents` | Private | National ID, police clearance, etc. |
| `app-assets` | Public | App images, icons |

Upload path format: `{bucket}/{user_id}/{filename}`

Example: `documents/550e8400-e29b-41d4/national_id.jpg`
