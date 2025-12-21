# 🔐 Google OAuth Sozlash - Qadamma-Qadam Ko'rsatma

## ✅ SHA-1 Fingerprint Oldingiz!

Endi quyidagi qadamlarni bajaring:

---

## 📋 1-QADAM: Google Cloud Console - OAuth 2.0 Client ID Yaratish

### 1.1. Google Cloud Console ga kiring
1. [Google Cloud Console](https://console.cloud.google.com/) ga kiring
2. O'zingizning loyihangizni tanlang (yoki yangi loyiha yarating)

### 1.2. OAuth Consent Screen sozlang
1. **APIs & Services → OAuth consent screen** ga kiring
2. **User Type** tanlang:
   - **External** (umumiy foydalanish uchun)
   - **Internal** (faqat Google Workspace uchun)
3. **App information** to'ldiring:
   - **App name**: `BarakaParts` (yoki o'zingiz tanlagan nom)
   - **User support email**: O'zingizning emailingiz
   - **Developer contact information**: O'zingizning emailingiz
4. **Save and Continue** bosing
5. **Scopes** bo'limida **Save and Continue** bosing (default scopes yetarli)
6. **Test users** bo'limida (agar External tanlagan bo'lsangiz):
   - O'zingizning emailingizni qo'shing
   - **Save and Continue** bosing
7. **Summary** bo'limida **Back to Dashboard** bosing

### 1.3. OAuth 2.0 Client ID yarating
1. **APIs & Services → Credentials** ga kiring
2. **+ CREATE CREDENTIALS** → **OAuth client ID** ni tanlang
3. **Application type** tanlang:
   - **Android** (Android uchun)
   - **iOS** (iOS uchun)
   - **Web application** (Web uchun)

#### Android uchun:
1. **Application type**: **Android**
2. **Name**: `BarakaParts Android`
3. **Package name**: `com.probaraka.barakaparts` ⚠️ **MUHIM: To'g'ri package nomi!**
4. **SHA-1 certificate fingerprint**: SHA-1 ni qo'shing (siz oldingiz)
   ```
   SHA-1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
   ```
5. **CREATE** bosing
6. **Client ID** va **Client Secret** ni nusxalab saqlang!

#### iOS uchun:
1. **Application type**: **iOS**
2. **Name**: `BarakaParts iOS`
3. **Bundle ID**: `com.probaraka.barakaparts` ⚠️ **MUHIM: To'g'ri Bundle ID!**
4. **App Store ID**: (ixtiyoriy, agar App Store'da bo'lsa)
5. **CREATE** bosing
6. **Client ID** ni nusxalab saqlang!

#### Web application uchun (agar web versiya bo'lsa):
1. **Application type**: **Web application**
2. **Name**: `BarakaParts Web`
3. **Authorized redirect URIs** ga qo'shing:
   ```
   https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
   ```
   ⚠️ **YOUR_PROJECT_ID** ni o'zingizning Supabase project ID bilan almashtiring!
4. **CREATE** bosing
5. **Client ID** va **Client Secret** ni nusxalab saqlang!

---

## 📋 2-QADAM: Supabase Dashboard - Google Provider Sozlash

### 2.1. Supabase Dashboard ga kiring
1. [Supabase Dashboard](https://app.supabase.com/) ga kiring
2. O'zingizning loyihangizni tanlang

### 2.2. Google Provider ni yoqing
1. **Authentication → Providers** ga kiring
2. **Google** provider ni toping
3. **Enable Google provider** ni yoqing (toggle)

### 2.3. Google OAuth ma'lumotlarini kiriting
1. **Client ID (for OAuth)**: Google Cloud Console'dan olgan **Client ID** ni kiriting
2. **Client Secret (for OAuth)**: Google Cloud Console'dan olgan **Client Secret** ni kiriting
   ⚠️ **Eslatma**: iOS uchun Client Secret bo'lmaydi, faqat Client ID yetarli

### 2.4. Redirect URLs ni sozlang
1. **Redirect URLs** bo'limiga quyidagilarni qo'shing:

#### Android uchun:
```
com.probaraka.barakaparts://login-callback
```

#### iOS uchun:
```
com.probaraka.barakaparts://login-callback
```

#### Web uchun (agar web versiya bo'lsa):
```
https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
```

⚠️ **MUHIM**: Har bir platforma uchun alohida qator qo'shing!

### 2.5. Authorized client IDs (Android uchun)
1. **Authorized client IDs** bo'limiga **SHA-1 fingerprint** ni qo'shing
2. Format: `SHA1:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX`
   ⚠️ **Eslatma**: `SHA1:` prefiksini qo'shing!

### 2.6. Saqlash
1. Barcha ma'lumotlarni to'ldirgandan keyin **Save** bosing
2. Xabarni kuting: **Settings saved successfully**

---

## 📋 3-QADAM: Flutter Kodini Tekshirish

### 3.1. app_constants.dart tekshirish
Fayl: `lib/core/constants/app_constants.dart`

Quyidagi kod to'g'ri bo'lishi kerak:
```dart
static String get mobileDeepLinkUrl {
  return 'com.probaraka.barakaparts://login-callback';
}
```

### 3.2. AndroidManifest.xml tekshirish
Fayl: `android/app/src/main/AndroidManifest.xml`

Quyidagi intent filter bo'lishi kerak:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.probaraka.barakaparts" />
</intent-filter>
```

### 3.3. iOS Info.plist tekshirish (agar iOS uchun bo'lsa)
Fayl: `ios/Runner/Info.plist`

Quyidagi kod bo'lishi kerak:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.probaraka.barakaparts</string>
        </array>
    </dict>
</array>
```

---

## 📋 4-QADAM: Test Qilish

### 4.1. Flutter loyihasini tozalash
```bash
flutter clean
flutter pub get
```

### 4.2. Android uchun test
```bash
flutter run
```

### 4.3. Google Sign-In ni test qilish
1. Ilovani ishga tushiring
2. **Login** sahifasiga kiring
3. **Google bilan kirish** tugmasini bosing
4. Google akkauntingizni tanlang
5. Ruxsat berish tugmasini bosing
6. Ilovaga qaytib kelishingiz kerak va tizimga kirgan bo'lishingiz kerak

---

## ❌ Xatoliklar va Yechimlar

### Xatolik 1: "Unsupported provider: provider is not enabled"
**Sabab**: Supabase Dashboard'da Google provider yoqilmagan
**Yechim**: 
1. Supabase Dashboard → Authentication → Providers → Google
2. **Enable Google provider** ni yoqing
3. **Save** bosing

### Xatolik 2: "redirect_uri_mismatch"
**Sabab**: Redirect URL to'g'ri sozlanmagan
**Yechim**:
1. Supabase Dashboard'da **Redirect URLs** ga qo'shing:
   ```
   com.probaraka.barakaparts://login-callback
   ```
2. Google Cloud Console'da **Authorized redirect URIs** ga qo'shing:
   ```
   com.probaraka.barakaparts://login-callback
   ```

### Xatolik 3: "Invalid client ID"
**Sabab**: Google Cloud Console'dan olingan Client ID noto'g'ri
**Yechim**:
1. Google Cloud Console → Credentials ga kiring
2. To'g'ri Client ID ni nusxalang
3. Supabase Dashboard'ga qo'ying

### Xatolik 4: "SHA-1 fingerprint mismatch" (Android)
**Sabab**: SHA-1 fingerprint to'g'ri qo'shilmagan
**Yechim**:
1. Supabase Dashboard → Authentication → Providers → Google
2. **Authorized client IDs** ga SHA-1 ni qo'shing:
   ```
   SHA1:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
   ```
   ⚠️ **MUHIM**: `SHA1:` prefiksini qo'shing!

### Xatolik 5: "Package name mismatch" (Android)
**Sabab**: Package nomi to'g'ri sozlanmagan
**Yechim**:
1. Google Cloud Console'da OAuth Client ID ni tekshiring
2. **Package name** `com.probaraka.barakaparts` bo'lishi kerak
3. Agar noto'g'ri bo'lsa, yangi OAuth Client ID yarating

---

## ✅ Checklist

### Google Cloud Console:
- [ ] OAuth consent screen sozlangan
- [ ] Android OAuth Client ID yaratilgan
- [ ] iOS OAuth Client ID yaratilgan (agar iOS uchun bo'lsa)
- [ ] Web OAuth Client ID yaratilgan (agar web uchun bo'lsa)
- [ ] SHA-1 fingerprint qo'shilgan (Android)
- [ ] Package name to'g'ri: `com.probaraka.barakaparts`

### Supabase Dashboard:
- [ ] Google provider yoqilgan
- [ ] Client ID kiritilgan
- [ ] Client Secret kiritilgan (Android/Web uchun)
- [ ] Redirect URLs qo'shilgan:
  - [ ] `com.probaraka.barakaparts://login-callback` (Android)
  - [ ] `com.probaraka.barakaparts://login-callback` (iOS)
  - [ ] `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback` (Web)
- [ ] Authorized client IDs ga SHA-1 qo'shilgan (Android)

### Flutter Kod:
- [ ] `app_constants.dart` da `mobileDeepLinkUrl` to'g'ri
- [ ] `AndroidManifest.xml` da intent filter qo'shilgan
- [ ] `Info.plist` da URL scheme qo'shilgan (iOS)

### Test:
- [ ] Ilova ishga tushadi
- [ ] Google Sign-In tugmasi ishlaydi
- [ ] Google akkaunt tanlash ekrani ochiladi
- [ ] Ruxsat berishdan keyin ilovaga qaytadi
- [ ] Tizimga muvaffaqiyatli kiriladi

---

## 🎉 Tugadi!

Agar barcha qadamlarni to'g'ri bajarsangiz, Google OAuth ishlashi kerak!

Agar muammo bo'lsa, yuqoridagi **Xatoliklar va Yechimlar** bo'limini tekshiring.

---

## 📞 Qo'shimcha Yordam

Agar muammo bo'lsa:
1. Flutter console'da xatolik xabarlarini tekshiring
2. Supabase Dashboard → Logs bo'limida xatoliklarni ko'ring
3. Google Cloud Console → APIs & Services → Credentials da OAuth Client ID ni tekshiring


















