# ✅ Package Nomi O'zgartirildi: `com.probaraka.barakaparts`

## 🎉 Muvaffaqiyatli O'zgartirildi!

**Yangi Package Nomi**: `com.probaraka.barakaparts`

---

## ✅ O'zgartirilgan Fayllar

### 1. ✅ Android
- **`android/app/build.gradle.kts`**
  - `namespace = "com.probaraka.barakaparts"`
  - `applicationId = "com.probaraka.barakaparts"`

- **`android/app/src/main/kotlin/com/probaraka/barakaparts/MainActivity.kt`** (YANGI)
  - `package com.probaraka.barakaparts`
  - Eski fayl o'chirildi: `com/example/parts_control/`

- **`android/app/src/main/AndroidManifest.xml`**
  - Deep link intent filter qo'shildi:
    ```xml
    <data android:scheme="com.probaraka.barakaparts" />
    ```

### 2. ✅ iOS
- **`ios/Runner.xcodeproj/project.pbxproj`**
  - Barcha `PRODUCT_BUNDLE_IDENTIFIER` o'zgartirildi:
    - `com.probaraka.barakaparts` (main app)
    - `com.probaraka.barakaparts.RunnerTests` (test bundle)

### 3. ✅ Flutter
- **`lib/core/constants/app_constants.dart`**
  - `mobileDeepLinkUrl = 'com.probaraka.barakaparts://login-callback'`

---

## 🔐 Keyingi Qadamlar (Siz Bajarishingiz Kerak)

### ⚠️ MUHIM: Quyidagilarni qilishingiz kerak!

### 1. Supabase Dashboard

1. **Authentication → Providers → Google** ga kiring
2. **Redirect URLs** bo'limiga qo'shing:
   ```
   com.probaraka.barakaparts://login-callback
   ```
3. **Save** bosing

### 2. Google Cloud Console

1. [Google Cloud Console](https://console.cloud.google.com/) ga kiring
2. **APIs & Services → Credentials** ga kiring
3. OAuth 2.0 Client ID ni tanlang
4. **Authorized redirect URIs** ga qo'shing:
   ```
   com.probaraka.barakaparts://login-callback
   ```
5. **Save** bosing

### 3. SHA-1 Fingerprint (Android uchun)

Yangi SHA-1 olish:
```bash
cd android
./gradlew signingReport
```

Yoki:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**SHA-1** ni nusxalab, **Supabase Dashboard → Authentication → Providers → Google → Authorized client IDs** ga qo'shing.

---

## ✅ Test Qilish

```bash
# Clean
flutter clean

# Dependencies
flutter pub get

# Android clean
cd android && ./gradlew clean && cd ..

# Run
flutter run
```

---

## 📋 Checklist

### ✅ Bajarildi (Men qildim):
- [x] Android build.gradle.kts - namespace va applicationId
- [x] MainActivity.kt - package declaration va joylashuv
- [x] lib/core/constants/app_constants.dart - mobileDeepLinkUrl
- [x] AndroidManifest.xml - deep link intent filter
- [x] iOS project.pbxproj - Bundle Identifier

### ⚠️ Siz qilishingiz kerak:
- [ ] Supabase Dashboard - OAuth redirect URLs
- [ ] Google Cloud Console - OAuth redirect URIs
- [ ] SHA-1 fingerprint qo'shish (Android)

---

## 🎉 Tugadi!

Package nomi muvaffaqiyatli o'zgartirildi: **`com.probaraka.barakaparts`**

Endi faqat Supabase va Google Cloud Console sozlamalarini yangilashingiz kerak!

---

## 📝 Eslatma

Agar Google OAuth ishlamasa, quyidagilarni tekshiring:
1. Supabase Dashboard'da Google provider yoqilganmi?
2. Redirect URL to'g'ri qo'shilganmi?
3. Google Cloud Console'da redirect URI qo'shilganmi?
4. SHA-1 fingerprint qo'shilganmi? (Android)





































