# 🚀 Google OAuth - Tezkor Boshlash (SHA-1 Oldingiz!)

## ✅ Sizda Bor:
- ✅ SHA-1 Fingerprint
- ✅ Package nomi: `com.probaraka.barakaparts`

---

## 📋 3-QADAM: Google Cloud Console

### 1. OAuth 2.0 Client ID Yaratish

1. [Google Cloud Console](https://console.cloud.google.com/) ga kiring
2. **APIs & Services → Credentials** ga kiring
3. **+ CREATE CREDENTIALS → OAuth client ID**
4. **Application type**: **Android** tanlang
5. To'ldiring:
   - **Name**: `BarakaParts Android`
   - **Package name**: `com.probaraka.barakaparts`
   - **SHA-1 certificate fingerprint**: SHA-1 ni qo'shing (siz oldingiz)
6. **CREATE** bosing
7. **Client ID** ni nusxalab saqlang!

---

## 📋 2-QADAM: Supabase Dashboard

### 1. Google Provider ni Yoqing

1. [Supabase Dashboard](https://app.supabase.com/) ga kiring
2. **Authentication → Providers** ga kiring
3. **Google** ni toping va **Enable** qiling

### 2. OAuth Ma'lumotlarini Kiriting

1. **Client ID**: Google Cloud Console'dan olgan Client ID ni kiriting
2. **Client Secret**: (Android uchun bo'lmaydi, bo'sh qoldiring yoki Web uchun yaratilgan bo'lsa, uni kiriting)

### 3. Redirect URLs Qo'shing

**Redirect URLs** bo'limiga qo'shing:
```
com.probaraka.barakaparts://login-callback
```

### 4. Authorized client IDs (SHA-1)

**Authorized client IDs** bo'limiga qo'shing:
```
SHA1:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```
⚠️ **MUHIM**: `SHA1:` prefiksini qo'shing!

### 5. Save Bosing

**Save** bosing va xabarni kuting: **Settings saved successfully**

---

## ✅ Test Qilish

```bash
flutter clean
flutter pub get
flutter run
```

1. Ilovani ishga tushiring
2. **Google bilan kirish** tugmasini bosing
3. Google akkaunt tanlang
4. Ruxsat berish tugmasini bosing
5. Ilovaga qaytib kelishingiz kerak!

---

## ❌ Agar Xatolik Bo'lsa

### "Unsupported provider"
→ Supabase Dashboard'da Google provider yoqilmagan. **Enable** qiling!

### "redirect_uri_mismatch"
→ Redirect URL to'g'ri qo'shilmagan. Tekshiring:
- Supabase: `com.probaraka.barakaparts://login-callback`
- Google Cloud: `com.probaraka.barakaparts://login-callback`

### "SHA-1 mismatch"
→ SHA-1 to'g'ri qo'shilmagan. Tekshiring:
- Format: `SHA1:XX:XX:XX:...` (SHA1: prefiksi bor bo'lishi kerak!)

---

## ✅ Checklist

- [ ] Google Cloud Console'da Android OAuth Client ID yaratildi
- [ ] Package name: `com.probaraka.barakaparts`
- [ ] SHA-1 qo'shildi
- [ ] Supabase Dashboard'da Google provider yoqildi
- [ ] Client ID kiritildi
- [ ] Redirect URL qo'shildi: `com.probaraka.barakaparts://login-callback`
- [ ] SHA-1 qo'shildi (format: `SHA1:XX:XX:XX:...`)
- [ ] Save bosing
- [ ] Test qilindi

---

## 🎉 Tugadi!

Agar barcha qadamlarni to'g'ri bajarsangiz, Google OAuth ishlashi kerak!











