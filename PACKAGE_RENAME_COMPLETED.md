# ✅ Package Nomi O'zgartirildi!

## 🎉 Yangi Package Nomi

**Yangi nom**: `com.probaraka.barakaparts`

---

## ✅ O'zgartirilgan Fayllar

### 1. ✅ Android - build.gradle.kts
- **Fayl**: `android/app/build.gradle.kts`
- **O'zgartirildi**: 
  - `namespace = "com.probaraka.barakaparts"`
  - `applicationId = "com.probaraka.barakaparts"`

### 2. ✅ Kotlin MainActivity.kt
- **Yangi joylashuv**: `android/app/src/main/kotlin/com/probaraka/barakaparts/MainActivity.kt`
- **Package**: `package com.probaraka.barakaparts`
- **Eski papka o'chirildi**: `com/example/parts_control`

### 3. ✅ Deep Link URL
- **Fayl**: `lib/core/constants/app_constants.dart`
- **O'zgartirildi**: `com.probaraka.barakaparts://login-callback`

### 4. ✅ AndroidManifest.xml
- **Fayl**: `android/app/src/main/AndroidManifest.xml`
- **Qo'shildi**: Deep link intent filter
  ```xml
  <data android:scheme="com.probaraka.barakaparts" />
  ```

### 5. ✅ iOS Bundle Identifier
- **Fayl**: `ios/Runner.xcodeproj/project.pbxproj`
- **O'zgartirildi**: Barcha joylarda `com.probaraka.barakaparts`

---

## 🔐 Keyingi Qadamlar (Siz Bajarishingiz Kerak)

### 1. Supabase Dashboard

1. **Authentication → Providers → Google** ga kiring
2. **Redirect URLs** ga qo'shing:
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

SHA-1 ni nusxalab, **Supabase Dashboard → Authentication → Providers → Google → Authorized client IDs** ga qo'shing.

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

- [x] Android build.gradle.kts - namespace va applicationId
- [x] MainActivity.kt - package declaration va joylashuv
- [x] lib/core/constants/app_constants.dart - mobileDeepLinkUrl
- [x] AndroidManifest.xml - deep link intent filter
- [x] iOS project.pbxproj - Bundle Identifier
- [ ] Supabase Dashboard - OAuth redirect URLs (siz qilishingiz kerak)
- [ ] Google Cloud Console - OAuth redirect URIs (siz qilishingiz kerak)
- [ ] SHA-1 fingerprint qo'shish (siz qilishingiz kerak)

---

## 🎉 Tugadi!

Package nomi muvaffaqiyatli o'zgartirildi: `com.probaraka.barakaparts`

Endi faqat Supabase va Google Cloud Console sozlamalarini yangilashingiz kerak!




















