# 🔐 Google OAuth Setup Guide - Step by Step

## 📋 Prerequisites

- Google Cloud Console account
- Supabase project with admin access
- Flutter app package name: `com.probaraka.barakaparts`

---

## 🎯 Part 1: Google Cloud Console Setup

### Step 1: Create OAuth 2.0 Client ID for Android

1. **Go to Google Cloud Console**
   - URL: https://console.cloud.google.com/
   - Select your project (or create new one)

2. **Navigate to Credentials**
   - Left sidebar → **APIs & Services** → **Credentials**

3. **Create OAuth Consent Screen** (if not done)
   - Click **OAuth consent screen** (top)
   - Select **External** (for public apps)
   - Fill required fields:
     - **App name**: `BarakaParts`
     - **User support email**: Your email
     - **Developer contact**: Your email
   - Click **Save and Continue**
   - **Scopes**: Click **Save and Continue** (default scopes OK)
   - **Test users**: Add your email, click **Save and Continue**
   - **Summary**: Click **Back to Dashboard**

4. **Create Android OAuth Client ID**
   - Go back to **Credentials** page
   - Click **+ CREATE CREDENTIALS** → **OAuth client ID**
   - **Application type**: Select **Android**
   - Fill in:
     - **Name**: `BarakaParts Android`
     - **Package name**: `com.probaraka.barakaparts` ⚠️ **MUST MATCH EXACTLY**
     - **SHA-1 certificate fingerprint**: Get from command below
   - Click **CREATE**
   - **Copy the Client ID** (you'll need it for Supabase)

5. **Get SHA-1 Fingerprint** (for Android)
   
   **For Debug Keystore**:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   
   Look for `SHA1:` in the output, copy the value (without `SHA1:` prefix)
   
   **OR manually**:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   
   Copy the **SHA-1** value (format: `XX:XX:XX:XX:...`)

---

### Step 2: Create OAuth 2.0 Client ID for Web

1. **Still in Google Cloud Console → Credentials**

2. **Create Web OAuth Client ID**
   - Click **+ CREATE CREDENTIALS** → **OAuth client ID**
   - **Application type**: Select **Web application**
   - Fill in:
     - **Name**: `BarakaParts Web`
     - **Authorized redirect URIs**: Add this EXACT URL:
       ```
       https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
       ```
       ⚠️ Replace `YOUR_PROJECT_ID` with your actual Supabase project ID
       (Find it in Supabase Dashboard → Settings → API → Project URL)
   - Click **CREATE**
   - **Copy BOTH Client ID AND Client Secret** (you'll need both for Supabase)

---

### Step 3: Create OAuth 2.0 Client ID for iOS (if needed)

1. **Still in Google Cloud Console → Credentials**

2. **Create iOS OAuth Client ID**
   - Click **+ CREATE CREDENTIALS** → **OAuth client ID**
   - **Application type**: Select **iOS**
   - Fill in:
     - **Name**: `BarakaParts iOS`
     - **Bundle ID**: `com.probaraka.barakaparts` ⚠️ **MUST MATCH EXACTLY**
   - Click **CREATE**
   - **Copy the Client ID**

---

## 🎯 Part 2: Supabase Dashboard Setup

### Step 1: Enable Google Provider

1. **Go to Supabase Dashboard**
   - URL: https://app.supabase.com/
   - Select your project

2. **Navigate to Authentication → Providers**
   - Left sidebar → **Authentication** → **Providers**

3. **Enable Google Provider**
   - Find **Google** in the list
   - Toggle **Enable Google provider** to **ON**

---

### Step 2: Configure Google OAuth Credentials

1. **Still in Authentication → Providers → Google**

2. **Enter Credentials**
   - **Client ID (for OAuth)**: 
     - Paste **Web Application Client ID** from Google Cloud Console
     - ⚠️ Use Web Client ID (not Android/iOS Client ID)
   - **Client Secret (for OAuth)**:
     - Paste **Web Application Client Secret** from Google Cloud Console
     - ⚠️ Only Web applications have Client Secret

3. **Add Redirect URLs**
   - In **Redirect URLs** section, click **Add URL**
   - Add these URLs (one per line):
     ```
     https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
     com.probaraka.barakaparts://login-callback
     ```
     ⚠️ Replace `YOUR_PROJECT_ID` with your actual Supabase project ID
     ⚠️ First URL is for Web, second is for Android/iOS deep link

4. **Add Authorized Client IDs** (for Android)
   - In **Authorized client IDs** section, click **Add**
   - Enter in this EXACT format:
     ```
     SHA1:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
     ```
     ⚠️ Replace `XX:XX:...` with your SHA-1 fingerprint from Step 1.5
     ⚠️ **MUST include `SHA1:` prefix**
     ⚠️ Use the SHA-1 from your debug keystore (for development)

5. **Save Configuration**
   - Click **Save** button at bottom
   - Wait for confirmation: "Settings saved successfully"

---

## 🎯 Part 3: Verify Configuration

### Check 1: Google Cloud Console
- ✅ Android OAuth Client ID created with package: `com.probaraka.barakaparts`
- ✅ Web OAuth Client ID created with redirect: `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`
- ✅ SHA-1 fingerprint copied

### Check 2: Supabase Dashboard
- ✅ Google provider enabled (toggle ON)
- ✅ Client ID entered (Web Application Client ID)
- ✅ Client Secret entered (Web Application Client Secret)
- ✅ Redirect URLs added:
  - `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`
  - `com.probaraka.barakaparts://login-callback`
- ✅ Authorized Client IDs added: `SHA1:XX:XX:...`

---

## 🧪 Part 4: Test Google OAuth

1. **Run your Flutter app**
   ```bash
   flutter run
   ```

2. **Click "Continue with Google"**

3. **Expected Flow**:
   - Browser/WebView opens
   - Google sign-in page appears
   - Select Google account
   - Grant permissions
   - Redirects back to app
   - **App navigates to Home screen** (NOT login screen)

4. **If Error 400: redirect_uri_mismatch**:
   - Check redirect URLs match EXACTLY in both Google Cloud Console and Supabase
   - Wait 1-2 minutes for changes to propagate
   - Try again

5. **If "Provider not enabled"**:
   - Verify Google provider toggle is ON in Supabase
   - Click Save again

---

## 📝 Summary of Required Values

### Google Cloud Console:
- **Android Client ID**: `XXXXX.apps.googleusercontent.com`
- **Web Client ID**: `XXXXX.apps.googleusercontent.com`
- **Web Client Secret**: `GOCSPX-XXXXX`
- **SHA-1 Fingerprint**: `XX:XX:XX:XX:...`

### Supabase Dashboard:
- **Client ID**: [Web Client ID from Google]
- **Client Secret**: [Web Client Secret from Google]
- **Redirect URLs**:
  - `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`
  - `com.probaraka.barakaparts://login-callback`
- **Authorized Client IDs**: `SHA1:XX:XX:XX:...`

---

## ✅ Done!

Your Google OAuth is now configured. Test it and verify it works!

---

## ⚠️ Common Issues

1. **"redirect_uri_mismatch"**: Redirect URLs don't match exactly
2. **"Provider not enabled"**: Toggle Google provider ON in Supabase
3. **"Invalid client"**: Wrong Client ID/Secret in Supabase
4. **SHA-1 mismatch**: Wrong SHA-1 or missing `SHA1:` prefix

Fix these by double-checking all values match exactly!











