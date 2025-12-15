# 🎯 Keyingi Qadamlar - GPT Prompt

## 📋 Asosiy Prompt (Copy-Paste Ready)

```
You are a senior Flutter + Supabase + Google OAuth configuration expert.

I have completed the Flutter code implementation for Google OAuth. Now I need to configure the external services.

CURRENT STATUS:
✅ Flutter code is ready and working
✅ Platform detection: Web uses Supabase callback, Mobile uses deep link
✅ Android deep link configured in AndroidManifest.xml
✅ iOS URL scheme configured in Info.plist
✅ Constants file has correct URLs:
   - Web: https://PROJECT_ID.supabase.co/auth/v1/callback
   - Mobile: com.probaraka.barakaparts://login-callback

WHAT I NEED:
Step-by-step instructions to configure Google OAuth in:
1. Google Cloud Console (for OAuth credentials)
2. Supabase Dashboard (for provider configuration)

SPECIFIC REQUIREMENTS:

For Google Cloud Console:
1. How to create OAuth 2.0 Client ID for Android
   - What fields to fill
   - Package name: com.probaraka.barakaparts
   - Redirect URI: com.probaraka.barakaparts://login-callback
   - How to get SHA-1 fingerprint
   - Where to add SHA-1

2. How to create OAuth 2.0 Client ID for Web
   - What fields to fill
   - Redirect URI: https://PROJECT_ID.supabase.co/auth/v1/callback
   - Where PROJECT_ID is my Supabase project ID

3. OAuth Consent Screen configuration
   - What information to provide
   - Test users setup

For Supabase Dashboard:
1. How to enable Google provider
   - Exact navigation path
   - What to toggle

2. Where to enter credentials
   - Client ID field location
   - Client Secret field location
   - Which Client ID to use (Android or Web)

3. Where to add redirect URLs
   - Exact section name
   - How to add multiple URLs
   - Format for each URL

4. Where to add authorized client IDs
   - For Android (SHA-1 fingerprint)
   - Format: SHA1:XX:XX:XX:...

VERIFICATION:
- How to test on Android device
- How to test on Web browser
- What console logs to check
- How to verify redirect URL is correct
- How to verify OAuth flow completes

TROUBLESHOOTING:
- What to do if Error 400 (redirect_uri_mismatch)
- What to do if "provider not enabled"
- What to do if SHA-1 mismatch
- How to verify URLs match exactly

OUTPUT FORMAT:
Provide clear, numbered step-by-step instructions with:
- Exact navigation paths (e.g., "Go to X → Click Y → Find Z")
- Exact field names
- Exact values to enter
- Screenshot descriptions
- Common mistakes to avoid
- Verification steps after each major section

Make it beginner-friendly and actionable. Assume I'm new to Google Cloud Console and Supabase Dashboard.
```

---

## 📋 Qisqa Variant

```
Help me configure Google OAuth for Flutter + Supabase app.

I need:
1. Google Cloud Console: Create OAuth Client IDs (Android + Web)
2. Supabase Dashboard: Enable Google provider and configure

My values:
- Package: com.probaraka.barakaparts
- Android redirect: com.probaraka.barakaparts://login-callback
- Web redirect: https://PROJECT_ID.supabase.co/auth/v1/callback

Provide step-by-step instructions with exact values.
```

---

## 📋 O'zbekcha Variant

```
Siz Google OAuth sozlash bo'yicha mutaxassissiz.

Mening Flutter + Supabase ilovam uchun Google OAuth ni sozlashim kerak.

Vazifam:
1. Google Cloud Console da OAuth Client ID yaratish (Android va Web uchun)
2. Supabase Dashboard da Google provider ni sozlash

Ilova ma'lumotlari:
- Package nomi: com.probaraka.barakaparts
- Android redirect URL: com.probaraka.barakaparts://login-callback
- Web redirect URL: https://PROJECT_ID.supabase.co/auth/v1/callback

Kerak:
- Qadamma-qadam ko'rsatma
- Qaysi bo'limga kirish kerak
- Qaysi maydonlarga nima yozish kerak
- SHA-1 fingerprint qanday olish
- Umumiy xatoliklar va yechimlari

O'zbek tilida, aniq va tushunarli ko'rsatma bering.
```

---

## 🎯 Eng To'liq Prompt (Barcha Detallar)

```
You are an expert in Google OAuth, Supabase, and Flutter integration.

CONTEXT:
I have a Flutter app with Supabase authentication. The Flutter code is complete and uses platform-specific redirect URLs:
- Web: https://PROJECT_ID.supabase.co/auth/v1/callback
- Android/iOS: com.probaraka.barakaparts://login-callback

TASK:
Provide comprehensive step-by-step instructions to configure Google OAuth in:
1. Google Cloud Console
2. Supabase Dashboard

DETAILED REQUIREMENTS:

PART 1: Google Cloud Console

A. OAuth Consent Screen:
   - How to navigate to it
   - What information to provide (app name, email, etc.)
   - User type selection (External vs Internal)
   - Test users configuration
   - Scopes configuration

B. OAuth 2.0 Client ID for Android:
   - How to create it
   - Application type selection
   - Name field: "BarakaParts Android"
   - Package name: com.probaraka.barakaparts
   - SHA-1 fingerprint:
     * How to get it (gradlew signingReport command)
     * Where to find it in output
     * Format: XX:XX:XX:XX:...
   - Where redirect URI is configured (if needed)

C. OAuth 2.0 Client ID for Web:
   - How to create it
   - Application type selection
   - Name field: "BarakaParts Web"
   - Authorized redirect URIs:
     * Exact URL: https://PROJECT_ID.supabase.co/auth/v1/callback
     * How to add it
     * Where PROJECT_ID comes from

D. Getting Credentials:
   - How to copy Client ID
   - How to copy Client Secret
   - Where to save them securely

PART 2: Supabase Dashboard

A. Enabling Google Provider:
   - Navigation path: Authentication → Providers → Google
   - How to toggle it ON
   - What happens when enabled

B. Entering Credentials:
   - Client ID field location
   - Client Secret field location
   - Which Client ID to use (Web or Android - explain which one)
   - Format requirements

C. Configuring Redirect URLs:
   - Where to find "Redirect URLs" section
   - How to add multiple URLs
   - Android URL: com.probaraka.barakaparts://login-callback
   - Web URL: https://PROJECT_ID.supabase.co/auth/v1/callback
   - Format requirements (exact match needed)

D. Authorized Client IDs (Android):
   - Where to find this section
   - How to add SHA-1 fingerprint
   - Format: SHA1:XX:XX:XX:XX:...
   - Why SHA1: prefix is needed

E. Saving Configuration:
   - Where to click Save
   - What confirmation to expect
   - How long changes take to propagate

PART 3: Verification & Testing

A. Android Testing:
   - How to run app on Android device
   - What console logs to check
   - Expected log output
   - How to trigger Google login
   - What to expect in browser
   - How to verify redirect back to app
   - How to verify user is logged in

B. Web Testing:
   - How to run app in Chrome
   - What console logs to check
   - Expected log output
   - How to trigger Google login
   - What to expect in browser
   - How to verify redirect
   - How to verify user is logged in

C. Common Issues:
   - Error 400: redirect_uri_mismatch
     * How to identify
     * How to fix
     * How to verify fix
   - "Provider not enabled" error
     * How to identify
     * How to fix
   - SHA-1 mismatch
     * How to identify
     * How to fix

OUTPUT FORMAT:
1. Use numbered steps (1, 2, 3...)
2. Use sub-steps (1.1, 1.2, 1.3...)
3. Include exact navigation paths
4. Include exact field names
5. Include exact values to enter
6. Include screenshot descriptions
7. Include verification steps
8. Include troubleshooting for each section

TONE:
- Beginner-friendly
- Clear and concise
- Actionable (use "Click", "Enter", "Navigate to")
- Include "why" explanations where helpful

Assume the user is new to both Google Cloud Console and Supabase Dashboard but has basic technical knowledge.
```

---

## 💡 Foydalanish

1. **Yuqoridagi promptlardan birini tanlang**
2. **Copy qiling**
3. **ChatGPT, Claude, yoki boshqa AI ga yuboring**
4. **AI dan aniq ko'rsatmalar oling**
5. **Ko'rsatmalarga amal qiling**

**Tavsiya**: "Eng To'liq Prompt" ni ishlatib, barcha ma'lumotlarni bir vaqtda oling.








