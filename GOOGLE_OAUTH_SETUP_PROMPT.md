# 🤖 Google OAuth Sozlash - GPT Prompt

## 📋 Prompt (Copy-Paste Ready)

```
You are a senior Supabase + Google OAuth configuration expert.

I have a Flutter app with Supabase authentication. I need to configure Google OAuth to work on both Web and Mobile (Android).

Current Status:
- Flutter code is ready with platform-specific redirect URLs
- Android deep link is configured: com.probaraka.barakaparts://login-callback
- Web callback URL: https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
- Package name: com.probaraka.barakaparts

My Task:
I need step-by-step instructions to configure Google OAuth in:
1. Google Cloud Console
2. Supabase Dashboard

Requirements:
- Provide EXACT steps with screenshots descriptions
- Show where to find each setting
- Provide EXACT values to enter
- Explain what each setting does
- Include troubleshooting for common errors

For Google Cloud Console:
- How to create OAuth 2.0 Client ID for Android
- How to create OAuth 2.0 Client ID for Web
- Where to add redirect URIs
- How to get SHA-1 fingerprint for Android
- Where to add SHA-1 fingerprint

For Supabase Dashboard:
- Where to enable Google provider
- Where to enter Client ID and Secret
- Where to add redirect URLs
- Where to add authorized client IDs (SHA-1)

Expected Output:
- Numbered step-by-step instructions
- Exact field names and values
- Screenshot descriptions (what to look for)
- Common mistakes to avoid
- Verification steps

Make the instructions clear and beginner-friendly.
```

---

## 📋 Qisqa Prompt (Tezkor)

```
You are a Google OAuth configuration expert.

Help me configure Google OAuth for my Flutter + Supabase app.

I need:
1. Google Cloud Console setup (Android + Web OAuth Client IDs)
2. Supabase Dashboard setup (Google provider configuration)

My app details:
- Package: com.probaraka.barakaparts
- Android redirect: com.probaraka.barakaparts://login-callback
- Web redirect: https://PROJECT_ID.supabase.co/auth/v1/callback

Provide step-by-step instructions with exact values to enter.
```

---

## 📋 O'zbekcha Prompt

```
Siz Google OAuth sozlash bo'yicha mutaxassissiz.

Mening Flutter + Supabase ilovam uchun Google OAuth ni sozlashim kerak.

Vazifam:
1. Google Cloud Console da sozlash
2. Supabase Dashboard da sozlash

Ilova ma'lumotlari:
- Package nomi: com.probaraka.barakaparts
- Android redirect URL: com.probaraka.barakaparts://login-callback
- Web redirect URL: https://PROJECT_ID.supabase.co/auth/v1/callback

Kerak:
- Qadamma-qadam ko'rsatma
- Qaysi maydonlarga nima yozish kerak
- SHA-1 fingerprint qanday olish
- Umumiy xatoliklar va yechimlari

O'zbek tilida, aniq va tushunarli ko'rsatma bering.
```

---

## 📋 Test Qilish uchun Prompt

```
You are a Flutter + Supabase testing expert.

I have configured Google OAuth. Help me test it properly.

Test Scenarios:
1. Test Google login on Android device
2. Test Google login on Web (Chrome)
3. Verify redirect URLs are correct
4. Check for common errors

What to check:
- Console logs show correct redirect URL
- OAuth flow completes successfully
- User profile is created automatically
- No Error 400 (redirect_uri_mismatch)
- No "provider not enabled" errors

Provide:
- Step-by-step testing checklist
- What logs to look for
- How to verify success
- How to debug failures
```

---

## 📋 Xatoliklar Tuzatish uchun Prompt

```
You are a Google OAuth troubleshooting expert.

I'm getting this error: [PASTE YOUR ERROR HERE]

My setup:
- Platform: [Android/Web]
- Redirect URL being used: [FROM LOGS]
- Configured in Google Cloud: [YES/NO]
- Configured in Supabase: [YES/NO]

Help me:
1. Identify the exact cause
2. Provide step-by-step fix
3. Verify the fix works
4. Prevent this error in future

Be specific and actionable.
```

---

## 🎯 Eng Yaxshi Prompt (Barcha Talablar)

```
You are a senior Google OAuth + Supabase configuration expert.

I have a Flutter app with Supabase authentication. I need to configure Google OAuth.

CURRENT STATE:
✅ Flutter code is ready
✅ Platform detection implemented
✅ Android deep link configured: com.probaraka.barakaparts://login-callback
✅ Web callback URL: https://PROJECT_ID.supabase.co/auth/v1/callback
✅ Package name: com.probaraka.barakaparts

MY TASK:
Configure Google OAuth in Google Cloud Console and Supabase Dashboard so that:
- Google login works on Android
- Google login works on Web (Chrome)
- No redirect_uri_mismatch errors
- User profiles are created automatically

REQUIREMENTS:
1. Google Cloud Console Setup:
   - Create OAuth 2.0 Client ID for Android
   - Create OAuth 2.0 Client ID for Web
   - Add redirect URIs to each
   - Get SHA-1 fingerprint for Android
   - Where to add SHA-1

2. Supabase Dashboard Setup:
   - Enable Google provider
   - Enter Client ID and Secret
   - Add redirect URLs (both mobile and web)
   - Add authorized client IDs (SHA-1 for Android)

3. Verification:
   - How to test on Android
   - How to test on Web
   - What logs to check
   - How to verify success

OUTPUT FORMAT:
- Numbered step-by-step instructions
- Exact field names and values
- Screenshot descriptions
- Common mistakes to avoid
- Troubleshooting guide

Make it beginner-friendly and actionable.
```

---

## 📝 Foydalanish

1. **Yuqoridagi promptlardan birini tanlang**
2. **Copy qiling**
3. **GPT ga yuboring**
4. **Ko'rsatmalarga amal qiling**

Yoki **"Eng Yaxshi Prompt"** ni ishlatib, barcha ma'lumotlarni bir vaqtda oling.


















