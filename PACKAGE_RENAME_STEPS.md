# 📦 Package Nomini O'zgartirish - Qadamma-Qadam

## Hozirgi Holat
- **Android Package**: `com.example.parts_control`
- **Deep Link**: `com.barakaparts://login-callback`

## Yangi Nom (O'zingiz tanlang)
**Misol**: `com.barakaparts.app`

---

## 🔧 QADAM 1: Android - build.gradle.kts

**Fayl**: `android/app/build.gradle.kts`

**O'zgartirish**:
```kotlin
android {
    namespace = "com.barakaparts.app"  // ← O'zgartiring
    // ...
    defaultConfig {
        applicationId = "com.barakaparts.app"  // ← O'zgartiring
    }
}
```

---

## 📁 QADAM 2: Kotlin Faylini Ko'chirish

### 2.1. Yangi papka yarating:
```bash
mkdir -p android/app/src/main/kotlin/com/barakaparts/app
```

### 2.2. Faylni ko'chiring:
```bash
# Windows PowerShell:
Move-Item android\app\src\main\kotlin\com\example\parts_control\MainActivity.kt `
          android\app\src\main\kotlin\com\barakaparts\app\MainActivity.kt

# Linux/Mac:
mv android/app/src/main/kotlin/com/example/parts_control/MainActivity.kt \
   android/app/src/main/kotlin/com/barakaparts/app/MainActivity.kt
```

### 2.3. MainActivity.kt ichidagi package nomini o'zgartiring:
```kotlin
package com.barakaparts.app  // ← Yangi nom
```

### 2.4. Eski papkani o'chiring:
```bash
# Windows:
Remove-Item -Recurse android\app\src\main\kotlin\com\example

# Linux/Mac:
rm -rf android/app/src/main/kotlin/com/example
```

---

## 🍎 QADAM 3: iOS - Info.plist

**Fayl**: `ios/Runner/Info.plist`

**Qidiring va o'zgartiring**:
```xml
<key>CFBundleIdentifier</key>
<string>com.barakaparts.app</string>  <!-- ← Yangi nom -->
```

---

## 🔗 QADAM 4: Deep Link URL

**Fayl**: `lib/core/constants/app_constants.dart`

**O'zgartirish**:
```dart
static String get mobileDeepLinkUrl {
  return 'com.barakaparts.app://login-callback';  // ← Yangi nom
}
```

---

## 📱 QADAM 5: AndroidManifest.xml (Deep Link)

**Fayl**: `android/app/src/main/AndroidManifest.xml`

**MainActivity ichiga qo'shing**:
```xml
<!-- Deep Link Intent Filter -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.barakaparts.app" />  <!-- ← Yangi nom -->
</intent-filter>
```

---

## 🔐 QADAM 6: Supabase OAuth Sozlamalari

### 6.1. Supabase Dashboard:
1. **Authentication → Providers → Google**
2. **Redirect URLs** ga qo'shing:
   ```
   com.barakaparts.app://login-callback
   ```

### 6.2. Google Cloud Console:
1. OAuth 2.0 Credentials
2. **Authorized redirect URIs** ga qo'shing:
   ```
   com.barakaparts.app://login-callback
   ```

---

## ✅ QADAM 7: Clean va Test

```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run
```

---

## 📋 Checklist

- [ ] `android/app/build.gradle.kts` - namespace va applicationId
- [ ] `MainActivity.kt` - package declaration va joylashuv
- [ ] `ios/Runner/Info.plist` - CFBundleIdentifier
- [ ] `lib/core/constants/app_constants.dart` - mobileDeepLinkUrl
- [ ] `AndroidManifest.xml` - deep link intent filter
- [ ] Supabase Dashboard - OAuth redirect URLs
- [ ] Google Cloud Console - OAuth redirect URIs
- [ ] `flutter clean` va test

---

## ⚠️ Eslatma

**Yangi package nomini tanlaganingizdan keyin**, barcha joylarda bir xil nom ishlatilganini tekshiring!






