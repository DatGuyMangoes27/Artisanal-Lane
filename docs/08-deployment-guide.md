# Deployment Guide

**Project:** Artisanal Lane -- Curated Craft Marketplace
**Version:** 1.0

---

## Table of Contents

1. [Supabase Setup](#1-supabase-setup)
2. [PayFast Integration](#2-payfast-integration)
3. [Flutter Mobile App -- Android](#3-flutter-mobile-app--android)
4. [Flutter Mobile App -- iOS](#4-flutter-mobile-app--ios)
5. [Admin Dashboard Deployment](#5-admin-dashboard-deployment)
6. [CI/CD with GitHub Actions](#6-cicd-with-github-actions)
7. [Environment Management](#7-environment-management)
8. [Post-Deployment Checklist](#8-post-deployment-checklist)

---

## 1. Supabase Setup

### 1.1 Create Project

1. Go to [https://supabase.com](https://supabase.com) and sign in.
2. Click "New Project" and configure:
   - **Name:** `artisanal-lane` (or `artisanal-lane-dev` for development)
   - **Database Password:** Generate a strong password and store it securely.
   - **Region:** Select the closest region to South Africa (e.g., `eu-west-1` or `af-south-1` if available).
3. Note the following from the project settings:
   - **Project URL:** `https://<project-ref>.supabase.co`
   - **Anon Key:** (public, safe to use in client)
   - **Service Role Key:** (secret, never expose to client)

### 1.2 Run Database Migrations

Execute the SQL from [04-database-schema.md](04-database-schema.md) in the Supabase SQL Editor in this order:

1. **Create tables** (Section 2: all `CREATE TABLE` statements).
2. **Create functions** (Section 5: `get_user_role`, `handle_new_user`, `update_updated_at`, `decrement_stock`).
3. **Create triggers** (Section 6: all `CREATE TRIGGER` statements).
4. **Enable RLS and create policies** (Section 3: all `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and `CREATE POLICY` statements).
5. **Create indexes** (Section 4: all `CREATE INDEX` statements).
6. **Insert seed data** (Section 7: categories and admin user).

### 1.3 Configure Storage Buckets

In the Supabase Dashboard, go to **Storage** and create:

| Bucket Name      | Public | File Size Limit | Allowed MIME Types                  |
| ---------------- | ------ | --------------- | ----------------------------------- |
| `product-images` | Yes    | 5 MB            | `image/jpeg`, `image/png`, `image/webp` |
| `shop-assets`    | Yes    | 5 MB            | `image/jpeg`, `image/png`, `image/webp` |
| `avatars`        | Yes    | 2 MB            | `image/jpeg`, `image/png`, `image/webp` |

Add storage RLS policies for each bucket:

```sql
-- product-images: Anyone can read, authenticated users can upload to their folder
CREATE POLICY "Public read product images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'product-images');

CREATE POLICY "Authenticated users upload product images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'product-images'
        AND auth.role() = 'authenticated'
    );

CREATE POLICY "Users delete own product images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'product-images'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Repeat similar policies for shop-assets and avatars buckets
```

### 1.4 Configure Authentication

In the Supabase Dashboard, go to **Authentication > Providers**:

1. **Email:** Enabled by default. Configure:
   - Confirm email: **Enabled**
   - Secure email change: **Enabled**
   - Custom SMTP (recommended for production): Configure with your email provider (e.g., SendGrid, Resend).

2. **Google OAuth:**
   - Go to [Google Cloud Console](https://console.cloud.google.com).
   - Create OAuth 2.0 credentials (Web application).
   - Add the Supabase callback URL: `https://<project-ref>.supabase.co/auth/v1/callback`
   - Enter Client ID and Client Secret in Supabase.

3. **Apple Sign-In:**
   - Requires Apple Developer account.
   - Create a Services ID in Apple Developer portal.
   - Configure the callback URL: `https://<project-ref>.supabase.co/auth/v1/callback`
   - Enter credentials in Supabase.

### 1.5 Deploy Edge Functions

Install the Supabase CLI:

```bash
npm install -g supabase
```

Login and link to your project:

```bash
supabase login
supabase link --project-ref <project-ref>
```

Create and deploy each Edge Function:

```bash
# Create function scaffolds
supabase functions new payfast-itn
supabase functions new create-payfast-subscription
supabase functions new create-checkout
supabase functions new release-escrow
supabase functions new generate-invite
supabase functions new process-refund
supabase functions new analytics

# Deploy all functions
supabase functions deploy payfast-itn --no-verify-jwt
supabase functions deploy create-payfast-subscription
supabase functions deploy create-checkout
supabase functions deploy release-escrow
supabase functions deploy generate-invite
supabase functions deploy process-refund
supabase functions deploy analytics
```

> Note: `payfast-itn` uses `--no-verify-jwt` because PayFast sends webhooks without a Supabase JWT. The function validates the PayFast signature instead.

Set Edge Function secrets:

```bash
supabase secrets set PAYFAST_MERCHANT_ID=<your_merchant_id>
supabase secrets set PAYFAST_MERCHANT_KEY=<your_merchant_key>
supabase secrets set PAYFAST_SANDBOX=true
```

If your PayFast account has a security passphrase configured, set it too:

```bash
supabase secrets set PAYFAST_PASSPHRASE=<your_passphrase>
```

---

## 2. PayFast Integration

### 2.1 Create PayFast Account

1. Register at [https://www.payfast.co.za](https://www.payfast.co.za).
2. Complete merchant verification (ID, bank details, business registration).
3. Note your:
   - **Merchant ID**
   - **Merchant Key**
   - **Passphrase** only if you enabled one in PayFast Security settings

### 2.2 Sandbox Testing

PayFast provides a sandbox environment for testing:

- **Sandbox Merchant ID:** `10000100`
- **Sandbox Merchant Key:** `46f0cd694581a`
- **Sandbox URL:** `https://sandbox.payfast.co.za/eng/process`

Configure the sandbox in your Edge Function environment variables:

```bash
supabase secrets set PAYFAST_SANDBOX=true
```

### 2.3 Configure Artisan Subscription Webhooks

In your PayFast dashboard:

1. Go to **Settings > Integration**.
2. Set the **Notify URL (ITN)** to: `https://<project-ref>.supabase.co/functions/v1/payfast-itn`
3. Set the **Return URL** to: `https://artisanlanesa.co.za/vendor/subscription/success`
4. Set the **Cancel URL** to: `https://artisanlanesa.co.za/vendor/subscription/error`

The mobile app recognizes those hosted web URLs and routes artisans back into the subscription screen automatically.

`create-payfast-subscription` is used only for artisan billing. Buyer checkout remains on TradeSafe through `create-checkout`.

### 2.4 Production Cutover

When ready for production:

1. Update Edge Function secrets with real credentials:

```bash
supabase secrets set PAYFAST_MERCHANT_ID=<real_merchant_id>
supabase secrets set PAYFAST_MERCHANT_KEY=<real_merchant_key>
supabase secrets set PAYFAST_SANDBOX=false
```

Set `PAYFAST_PASSPHRASE` only if production PayFast has a passphrase enabled.

2. Confirm `PAYFAST_SANDBOX=false` for both `create-payfast-subscription` and `payfast-itn`.

---

## 3. Flutter Mobile App -- Android

### 3.1 Prerequisites

- Flutter SDK 3.x installed
- Android Studio with Android SDK
- Java 17+

### 3.2 Configure Signing

1. Generate a keystore:

```bash
keytool -genkey -v -keystore artisanal-lane-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias artisanal-lane
```

2. Create `android/key.properties` (do NOT commit this file):

```properties
storePassword=<your_store_password>
keyPassword=<your_key_password>
keyAlias=artisanal-lane
storeFile=../artisanal-lane-release.jks
```

3. Update `android/app/build.gradle`:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 3.3 Configure App Details

Update `android/app/build.gradle`:

```groovy
android {
    namespace "co.za.artisanallane.app"
    defaultConfig {
        applicationId "co.za.artisanallane.app"
        minSdkVersion 23
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

### 3.4 Build Release APK/AAB

```bash
# Build App Bundle (recommended for Play Store)
flutter build appbundle --release --dart-define-from-file=.env.prod

# Build APK (for testing/sideloading)
flutter build apk --release --dart-define-from-file=.env.prod
```

### 3.5 Google Play Store Submission

1. Go to [Google Play Console](https://play.google.com/console).
2. Create a new application.
3. Fill in the store listing:
   - **App name:** Artisanal Lane
   - **Short description:** Discover curated South African artisan crafts
   - **Full description:** Detailed marketplace description
   - **Screenshots:** Phone and tablet screenshots
   - **Feature graphic:** 1024x500 banner
   - **App icon:** 512x512 high-res icon
4. Upload the AAB file to the production track (or internal testing first).
5. Complete the content rating questionnaire.
6. Set pricing (Free) and distribution (South Africa, or worldwide).
7. Submit for review.

---

## 4. Flutter Mobile App -- iOS

### 4.1 Prerequisites

- macOS with Xcode 15+
- Apple Developer account ($99/year)
- Flutter SDK 3.x
- CocoaPods installed

### 4.2 Configure Xcode Project

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Set the Bundle Identifier: `co.za.artisanallane.app`
3. Set the Display Name: `Artisanal Lane`
4. Set the Team to your Apple Developer account.
5. Set Deployment Target to iOS 14.0.

### 4.3 Provisioning and Certificates

1. In Apple Developer portal, create:
   - **App ID:** `co.za.artisanallane.app`
   - **Provisioning Profile:** Distribution (App Store)
2. In Xcode:
   - Enable "Automatically manage signing" for Debug.
   - For Release, select the distribution provisioning profile.

### 4.4 Configure Capabilities

In Xcode, enable:
- **Push Notifications** (for order updates)
- **Sign in with Apple** (for Apple social login)
- **Associated Domains** (for deep linking): `applinks:artisanallane.co.za`

### 4.5 Build and Archive

```bash
# Build iOS release
flutter build ios --release --dart-define-from-file=.env.prod

# Open Xcode for archiving
open ios/Runner.xcworkspace
```

In Xcode:
1. Select **Product > Archive**.
2. Once archived, click **Distribute App**.
3. Select **App Store Connect**.
4. Upload to App Store Connect.

### 4.6 App Store Connect Submission

1. Go to [App Store Connect](https://appstoreconnect.apple.com).
2. Create a new app:
   - **Bundle ID:** `co.za.artisanallane.app`
   - **Name:** Artisanal Lane
   - **Primary Language:** English
3. Fill in app information:
   - Screenshots for all required device sizes
   - App description, keywords, support URL
   - Privacy policy URL (required)
4. Select the uploaded build.
5. Submit for review.

---

## 5. Admin Dashboard Deployment

### 5.1 Build Flutter Web

```bash
flutter build web --release --dart-define-from-file=.env.prod --web-renderer canvaskit
```

The output is in `build/web/`.

### 5.2 Deploy to Vercel

1. Install the Vercel CLI:

```bash
npm install -g vercel
```

2. Deploy:

```bash
cd build/web
vercel --prod
```

3. Configure a custom domain (e.g., `admin.artisanallane.co.za`) in the Vercel dashboard.

### 5.3 Deploy to Netlify (Alternative)

1. Install the Netlify CLI:

```bash
npm install -g netlify-cli
```

2. Deploy:

```bash
cd build/web
netlify deploy --prod --dir=.
```

3. Configure custom domain in the Netlify dashboard.

### 5.4 SPA Routing Configuration

Flutter Web uses client-side routing. Configure the hosting platform to redirect all routes to `index.html`:

**Vercel (`vercel.json`):**

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**Netlify (`_redirects` file in `build/web/`):**

```
/*    /index.html   200
```

---

## 6. CI/CD with GitHub Actions

### 6.1 Repository Structure

```
.github/
  workflows/
    android-build.yml     # Android build and deploy
    ios-build.yml         # iOS build and deploy
    web-build.yml         # Admin dashboard build and deploy
    test.yml              # Run tests on PRs
```

### 6.2 Test Workflow

```yaml
# .github/workflows/test.yml
name: Test

on:
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

### 6.3 Android Build Workflow

```yaml
# .github/workflows/android-build.yml
name: Android Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'

      - name: Decode keystore
        run: echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 --decode > android/artisanal-lane-release.jks

      - name: Create key.properties
        run: |
          echo "storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}" > android/key.properties
          echo "keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}" >> android/key.properties
          echo "keyAlias=artisanal-lane" >> android/key.properties
          echo "storeFile=../artisanal-lane-release.jks" >> android/key.properties

      - name: Create .env.prod
        run: |
          echo "SUPABASE_URL=${{ secrets.SUPABASE_URL }}" > .env.prod
          echo "SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}" >> .env.prod
          echo "PAYFAST_SANDBOX=false" >> .env.prod

      - run: flutter pub get
      - run: flutter build appbundle --release --dart-define-from-file=.env.prod

      - name: Upload AAB
        uses: actions/upload-artifact@v4
        with:
          name: app-release.aab
          path: build/app/outputs/bundle/release/app-release.aab
```

### 6.4 iOS Build Workflow

```yaml
# .github/workflows/ios-build.yml
name: iOS Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'

      - name: Create .env.prod
        run: |
          echo "SUPABASE_URL=${{ secrets.SUPABASE_URL }}" > .env.prod
          echo "SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}" >> .env.prod
          echo "PAYFAST_SANDBOX=false" >> .env.prod

      - run: flutter pub get
      - run: flutter build ios --release --no-codesign --dart-define-from-file=.env.prod

      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: Runner.app
          path: build/ios/iphoneos/Runner.app
```

### 6.5 Admin Dashboard Build Workflow

```yaml
# .github/workflows/web-build.yml
name: Admin Dashboard Deploy

on:
  push:
    branches: [main]
    paths:
      - 'lib/**'
      - 'web/**'
      - 'pubspec.yaml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'

      - name: Create .env.prod
        run: |
          echo "SUPABASE_URL=${{ secrets.SUPABASE_URL }}" > .env.prod
          echo "SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}" >> .env.prod

      - run: flutter pub get
      - run: flutter build web --release --dart-define-from-file=.env.prod --web-renderer canvaskit

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: build/web
          vercel-args: '--prod'
```

### 6.6 GitHub Secrets Required

| Secret                       | Description                                |
| ---------------------------- | ------------------------------------------ |
| `SUPABASE_URL`               | Supabase project URL                       |
| `SUPABASE_ANON_KEY`          | Supabase anonymous / public key            |
| `ANDROID_KEYSTORE_BASE64`    | Base64-encoded keystore file               |
| `ANDROID_KEYSTORE_PASSWORD`  | Keystore password                          |
| `ANDROID_KEY_PASSWORD`       | Key password                               |
| `VERCEL_TOKEN`               | Vercel deployment token                    |
| `VERCEL_ORG_ID`              | Vercel organization ID                     |
| `VERCEL_PROJECT_ID`          | Vercel project ID                          |

---

## 7. Environment Management

### 7.1 Environment Files

| File        | Purpose                | Committed to Git? |
| ----------- | ---------------------- | ------------------ |
| `.env.dev`  | Development settings   | No                 |
| `.env.prod` | Production settings    | No                 |
| `.env.example` | Template for reference | Yes             |

### 7.2 .env.example

```
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here

# PayFast
PAYFAST_SANDBOX=true
```

### 7.3 .gitignore

Ensure the following are in `.gitignore`:

```
# Environment
.env
.env.dev
.env.prod

# Android signing
android/key.properties
*.jks

# Generated Dart files
*.g.dart
*.freezed.dart

# IDE
.idea/
.vscode/
*.iml

# Flutter/Dart
.dart_tool/
.packages
build/
```

### 7.4 Supabase Environments

For complete environment isolation, create two Supabase projects:

| Environment | Project Name         | Usage                    |
| ----------- | -------------------- | ------------------------ |
| Development | `artisanal-lane-dev` | Local development, testing |
| Production  | `artisanal-lane`     | Live app, real users      |

Both should have identical schemas. Use the Supabase CLI to manage migrations consistently:

```bash
# Generate migration from local changes
supabase db diff --use-migra -f <migration_name>

# Apply migrations to linked project
supabase db push
```

---

## 8. Post-Deployment Checklist

### Before Launch

- [ ] All database migrations applied to production Supabase.
- [ ] RLS policies tested for all roles (buyer, vendor, admin).
- [ ] Storage buckets created with correct access policies.
- [ ] PayFast production credentials configured in Edge Function secrets.
- [ ] PayFast ITN webhook URL set to production Edge Function URL.
- [ ] Google OAuth configured with production redirect URIs.
- [ ] Apple Sign-In configured with production redirect URIs.
- [ ] Custom SMTP configured for transactional emails.
- [ ] Admin user created and role set to `admin`.
- [ ] Seed categories inserted.
- [ ] Initial batch of invite codes generated.
- [ ] SSL/HTTPS verified on all endpoints.
- [ ] Deep linking configured and tested (iOS Universal Links, Android App Links).
- [ ] Push notification credentials configured (FCM for Android, APNs for iOS).

### App Store Submissions

- [ ] Android AAB uploaded to Google Play Console.
- [ ] Android store listing complete (screenshots, description, icon).
- [ ] Android content rating questionnaire completed.
- [ ] iOS IPA uploaded to App Store Connect.
- [ ] iOS store listing complete (screenshots, description, icon).
- [ ] iOS privacy policy URL provided.
- [ ] iOS App Review information filled out (demo account).

### Admin Dashboard

- [ ] Flutter Web build deployed to Vercel/Netlify.
- [ ] Custom domain configured (e.g., `admin.artisanallane.co.za`).
- [ ] HTTPS verified.
- [ ] SPA routing configured (all routes redirect to index.html).
- [ ] Admin user can log in and access all dashboard pages.

### Monitoring

- [ ] Supabase dashboard bookmarked for database and auth monitoring.
- [ ] Edge Function logs accessible for debugging payment webhooks.
- [ ] Google Play Console / App Store Connect set up for crash reporting.
- [ ] Error reporting service considered (e.g., Sentry for Flutter).
