# Winga App V3

A production-ready monorepo scaffold for Winga App V3, based on the architecture and Supabase model of the original Winga App repository.

## What is included
- Flutter mobile app with onboarding, auth, booking, profile, and payments screens
- Next.js admin console with dashboard and request management
- Customer and Winga Progressive Web App for mobile-like access without APKs
- Supabase client integration and copied migration assets from the original repository
- CI workflow for Flutter and Next.js

## Structure
```text
mobile/          Flutter app
admin/           Next.js admin app
pwa/             Next.js customer/Winga PWA
supabase/        Supabase SQL migrations and shared backend assets
docs/            migration summary
.github/         CI workflow
```

## Local setup
### Mobile
```bash
cd mobile
flutter pub get
flutter run
```

### Admin
```bash
cd admin
npm install
npm run dev
```

### PWA
```bash
cd pwa
npm install
npm run dev
```

### Supabase
1. Create a Supabase project.
2. Apply the SQL files in the supabase/migrations folder.
3. Set these environment variables:
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
   - NEXT_PUBLIC_SUPABASE_URL
   - NEXT_PUBLIC_SUPABASE_ANON_KEY

## Notes
This scaffold includes a mobile-like PWA for customers and Winga users so they can install the experience on iPhone, Android, and desktop without downloading an APK.
