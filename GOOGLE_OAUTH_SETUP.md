# 🔐 Google OAuth Setup Guide

## Error Message
```
{"code":400,"error_code":"validation_failed","msg":"Unsupported provider: provider is not enabled"}
```

## Problem
Google OAuth provider is **not enabled** in your Supabase Dashboard.

## Solution: Enable Google OAuth in Supabase

### Step 1: Enable Google Provider in Supabase Dashboard

1. **Go to Supabase Dashboard**
   - Open https://supabase.com/dashboard
   - Select your project

2. **Navigate to Authentication → Providers**
   - Click on "Authentication" in the left sidebar
   - Click on "Providers" tab

3. **Enable Google Provider**
   - Find "Google" in the list of providers
   - Toggle it **ON** (enable it)
   - Click "Save"

### Step 2: Configure Google OAuth Credentials

You need to get Google OAuth credentials from Google Cloud Console:

#### A. Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing)
3. Enable **Google+ API** (if not already enabled)

#### B. Create OAuth 2.0 Credentials

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth client ID**
3. Choose **Web application** (for Supabase)
4. Configure:
   - **Name**: Baraka Parts (or your app name)
   - **Authorized JavaScript origins**:
     ```
     https://your-project-ref.supabase.co
     ```
   - **Authorized redirect URIs**:
     ```
     https://your-project-ref.supabase.co/auth/v1/callback
     ```
5. Click **Create**
6. **Copy the Client ID and Client Secret**

#### C. Add Credentials to Supabase

1. Go back to Supabase Dashboard
2. **Authentication → Providers → Google**
3. Enter:
   - **Client ID**: (from Google Cloud Console)
   - **Client Secret**: (from Google Cloud Console)
4. Click **Save**

### Step 3: Configure Redirect URLs

#### For Web:
1. Go to **Authentication → URL Configuration**
2. Add to **Redirect URLs**:
   ```
   https://your-project-ref.supabase.co/auth/v1/callback
   ```

#### For Android:
1. Get your app's **SHA-1 fingerprint**:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Look for `SHA1` in the output (under `Variant: debug`)

2. In Supabase Dashboard → **Authentication → Providers → Google**:
   - Add SHA-1 fingerprint in **Authorized client IDs**
   - Add redirect URL: `com.barakaparts://login-callback` (update with your package name)

#### For iOS:
1. Get your **Bundle ID** from `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleIdentifier</key>
   <string>com.barakaparts</string>
   ```

2. In Supabase Dashboard → **Authentication → Providers → Google**:
   - Add Bundle ID in **Authorized client IDs**
   - Add redirect URL: `com.barakaparts://login-callback`

### Step 4: Update App Code (if needed)

Check your app's deep link configuration:

**File**: `lib/core/constants/app_constants.dart`

```dart
static String get mobileDeepLinkUrl {
  // Update this with your actual package name
  return 'com.barakaparts://login-callback';
}
```

**File**: `android/app/build.gradle.kts` (or `build.gradle`)

Make sure you have deep link intent filter:
```xml
<!-- In AndroidManifest.xml -->
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.barakaparts" />
</intent-filter>
```

## Testing

After enabling Google OAuth:

1. **Restart your app** (hot restart may not be enough)
2. Click "Continue with Google" button
3. Should open browser/WebView
4. Complete Google sign-in
5. Should redirect back to app

## Troubleshooting

### Error: "redirect_uri_mismatch"
**Solution**: 
- Check redirect URLs in Google Cloud Console match Supabase
- Check redirect URLs in Supabase Dashboard match your app

### Error: "invalid_client"
**Solution**:
- Verify Client ID and Secret are correct in Supabase
- Make sure you copied the full credentials (no extra spaces)

### Error: OAuth opens but doesn't redirect back
**Solution**:
- Check deep link configuration in Android/iOS
- Verify redirect URL in Supabase matches app scheme
- For mobile: Update `mobileDeepLinkUrl` in `app_constants.dart`

### Error: "provider is not enabled" (your current error)
**Solution**:
- ✅ Enable Google provider in Supabase Dashboard (Step 1 above)
- ✅ Add Client ID and Secret (Step 2 above)
- ✅ Save changes

## Quick Checklist

- [ ] Google provider enabled in Supabase Dashboard
- [ ] Google OAuth credentials created in Google Cloud Console
- [ ] Client ID and Secret added to Supabase
- [ ] Redirect URLs configured in Supabase
- [ ] Redirect URLs configured in Google Cloud Console
- [ ] For mobile: SHA-1 (Android) or Bundle ID (iOS) added
- [ ] Deep link URL updated in app code

## Summary

The error means Google OAuth is **not enabled** in Supabase. Follow the steps above to:
1. Enable Google provider
2. Add OAuth credentials
3. Configure redirect URLs
4. Test the flow

After completing these steps, Google sign-in should work! ✅













