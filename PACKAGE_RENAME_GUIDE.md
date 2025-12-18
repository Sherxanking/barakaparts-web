# 📦 Package Nomini O'zgartirish - Qadamma-Qadam Ko'rsatma

## ⚠️ MUHIM: Backup oling!

O'zgartirishdan oldin:
1. Git commit qiling: `git commit -am "Backup before package rename"`
2. Yoki loyihani nusxalang

---

## 📋 Hozirgi Package Nomi

**Hozirgi nom**: `com.example.parts_control`

**O'zgartirilishi kerak bo'lgan joylar**:
- Android: `com.example.parts_control`
- iOS: `com.example.partsControl` (ehtimol)
- Deep Link: `com.barakaparts://login-callback`

---

## 🎯 Qadam 1: Yangi Package Nomini Tanlang

**Format**: `com.yourcompany.appname`

**Misol**:
- `com.barakaparts.app`
- `com.barakaparts.inventory`
- `com.yourcompany.barakaparts`

**⚠️ Eslatma**: 
- Kichik harflar ishlating
- Underscore (_) yoki tire (-) ishlatishingiz mumkin
- Package nomi unique bo'lishi kerak

---

## 🔧 Qadam 2: Android Package Nomini O'zgartirish

### 2.1. `android/app/build.gradle.kts` faylini o'zgartiring

**Fayl**: `android/app/build.gradle.kts`

**O'zgartirish**:
```kotlin
android {
    namespace = "com.barakaparts.app"  // ← Yangi nom
    // ...
    defaultConfig {
        applicationId = "com.barakaparts.app"  // ← Yangi nom
        // ...
    }
}
```

**Misol** (hozirgi):
```kotlin
namespace = "com.example.parts_control"
applicationId = "com.example.parts_control"
```

**Yangi** (sizning nomingiz bilan):
```kotlin
namespace = "com.barakaparts.app"
applicationId = "com.barakaparts.app"
```

---

### 2.2. Kotlin faylini ko'chiring

**Hozirgi joylashuv**:
```
android/app/src/main/kotlin/com/example/parts_control/MainActivity.kt
```

**Yangi joylashuv** (package nomiga mos):
```
android/app/src/main/kotlin/com/barakaparts/app/MainActivity.kt
```

**Qadamlar**:
1. Yangi papkalarni yarating:
   ```bash
   mkdir -p android/app/src/main/kotlin/com/barakaparts/app
   ```

2. Eski faylni ko'chiring:
   ```bash
   mv android/app/src/main/kotlin/com/example/parts_control/MainActivity.kt \
      android/app/src/main/kotlin/com/barakaparts/app/MainActivity.kt
   ```

3. Eski papkalarni o'chiring:
   ```bash
   rm -rf android/app/src/main/kotlin/com/example
   ```

### 2.3. `MainActivity.kt` faylini o'zgartiring

**Fayl**: `android/app/src/main/kotlin/com/barakaparts/app/MainActivity.kt`

**O'zgartirish**:
```kotlin
package com.barakaparts.app  // ← Yangi package nomi

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

---

## 🍎 Qadam 3: iOS Package Nomini O'zgartirish

### 3.1. `ios/Runner/Info.plist` faylini o'zgartiring

**Fayl**: `ios/Runner/Info.plist`

**Qidiring**:
```xml
<key>CFBundleIdentifier</key>
<string>com.example.partsControl</string>
```

**O'zgartiring**:
```xml
<key>CFBundleIdentifier</key>
<string>com.barakaparts.app</string>
```

### 3.2. Xcode Project Settings (agar Xcode ishlatayotgan bo'lsangiz)

1. Xcode'da loyihani oching
2. Runner target'ni tanlang
3. General → Bundle Identifier ni o'zgartiring
4. Build Settings → Product Bundle Identifier ni o'zgartiring

---

## 🔗 Qadam 4: Deep Link URL'ni O'zgartirish

### 4.1. `lib/core/constants/app_constants.dart` faylini o'zgartiring

**Fayl**: `lib/core/constants/app_constants.dart`

**O'zgartirish**:
```dart
static String get mobileDeepLinkUrl {
  return 'com.barakaparts.app://login-callback';  // ← Yangi nom
}
```

---

### 4.2. AndroidManifest.xml'ga Deep Link Qo'shing (agar yo'q bo'lsa)

**Fayl**: `android/app/src/main/AndroidManifest.xml`

**Qo'shing** (MainActivity ichida):
```xml
<activity
    android:name=".MainActivity"
    ...>
    <!-- Existing intent filters -->
    
    <!-- Deep Link Intent Filter -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.barakaparts.app" />
    </intent-filter>
</activity>
```

---

## 🔐 Qadam 5: Supabase OAuth Sozlamalarini Yangilash

### 5.1. Supabase Dashboard'da

1. **Authentication → Providers → Google** ga kiring
2. **Authorized client IDs** bo'limida:
   - Android: Yangi SHA-1 fingerprint qo'shing
   - iOS: Yangi Bundle ID qo'shing
3. **Redirect URLs** ga yangi deep link qo'shing:
   ```
   com.barakaparts.app://login-callback
   ```

### 5.2. Google Cloud Console'da

1. OAuth 2.0 Credentials ga kiring
2. **Authorized redirect URIs** ga qo'shing:
   ```
   com.barakaparts.app://login-callback
   ```

---

## 🔑 Qadam 6: SHA-1 Fingerprint Olish (Android uchun)

Yangi package nomi bilan yangi SHA-1 olish kerak:

```bash
cd android
./gradlew signingReport
```

Yoki:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**SHA-1** ni nusxalab, Supabase Dashboard'ga qo'shing.

---

## ✅ Qadam 7: Test Qilish

### 7.1. Clean Build

```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
```

### 7.2. Build va Run

```bash
flutter run
```

### 7.3. Tekshirish

- [ ] App ishga tushadi
- [ ] Package nomi to'g'ri (Settings → Apps → Your App → Package name)
- [ ] Google OAuth ishlaydi
- [ ] Deep link ishlaydi (agar qo'shilgan bo'lsa)

---

## 📝 O'zgartirilgan Fayllar Ro'yxati

1. ✅ `android/app/build.gradle.kts` - namespace va applicationId
2. ✅ `android/app/src/main/kotlin/.../MainActivity.kt` - package declaration va joylashuv
3. ✅ `ios/Runner/Info.plist` - CFBundleIdentifier
4. ✅ `lib/core/constants/app_constants.dart` - mobileDeepLinkUrl
5. ✅ `android/app/src/main/AndroidManifest.xml` - deep link intent filter (qo'shish kerak bo'lsa)
6. ✅ Supabase Dashboard - OAuth redirect URLs
7. ✅ Google Cloud Console - OAuth redirect URIs

---

## ⚠️ Xatolar va Yechimlar

### Xato: "Package name does not match"
**Yechim**: Barcha joylarda bir xil nom ishlatilganini tekshiring

### Xato: "MainActivity not found"
**Yechim**: Kotlin fayl to'g'ri joyda ekanligini tekshiring

### Xato: "OAuth redirect mismatch"
**Yechim**: Supabase va Google Cloud Console'da redirect URL'lar bir xil ekanligini tekshiring

---

## 🎉 Tugagach

1. ✅ Git commit qiling
2. ✅ Test qiling
3. ✅ Production build yarating
4. ✅ Supabase sozlamalarini yangilang

---

## 📞 Yordam

Agar muammo bo'lsa:
1. `flutter clean` qiling
2. `flutter pub get` qiling
3. Android Studio'da "Invalidate Caches / Restart" qiling
4. Xcode'da "Clean Build Folder" qiling












