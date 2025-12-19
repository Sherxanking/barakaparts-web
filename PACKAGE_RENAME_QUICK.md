# 📦 Package Nomini O'zgartirish - Tezkor Ko'rsatma

## 🎯 Hozirgi Nom → Yangi Nom

**Hozirgi**: `com.example.parts_control`  
**Yangi**: `com.barakaparts.app` (yoki o'zingiz tanlagan nom)

---

## ✅ QADAM 1: Android - build.gradle.kts

**Fayl**: `android/app/build.gradle.kts`

**O'zgartirish** (9 va 24-qatorlar):
```kotlin
namespace = "com.barakaparts.app"  // ← 9-qator
applicationId = "com.barakaparts.app"  // ← 24-qator
```

---

## ✅ QADAM 2: Kotlin Faylini Ko'chirish

### Windows PowerShell:
```powershell
# Yangi papka yaratish
New-Item -ItemType Directory -Force -Path "android\app\src\main\kotlin\com\barakaparts\app"

# Faylni ko'chirish
Move-Item "android\app\src\main\kotlin\com\example\parts_control\MainActivity.kt" `
          "android\app\src\main\kotlin\com\barakaparts\app\MainActivity.kt"

# MainActivity.kt ichidagi package nomini o'zgartirish
(Get-Content "android\app\src\main\kotlin\com\barakaparts\app\MainActivity.kt") `
  -replace 'package com.example.parts_control', 'package com.barakaparts.app' | `
  Set-Content "android\app\src\main\kotlin\com\barakaparts\app\MainActivity.kt"

# Eski papkani o'chirish
Remove-Item -Recurse "android\app\src\main\kotlin\com\example"
```

### Linux/Mac:
```bash
# Yangi papka yaratish
mkdir -p android/app/src/main/kotlin/com/barakaparts/app

# Faylni ko'chirish
mv android/app/src/main/kotlin/com/example/parts_control/MainActivity.kt \
   android/app/src/main/kotlin/com/barakaparts/app/MainActivity.kt

# Package nomini o'zgartirish
sed -i 's/package com.example.parts_control/package com.barakaparts.app/g' \
    android/app/src/main/kotlin/com/barakaparts/app/MainActivity.kt

# Eski papkani o'chirish
rm -rf android/app/src/main/kotlin/com/example
```

---

## ✅ QADAM 3: Deep Link URL

**Fayl**: `lib/core/constants/app_constants.dart`

**64-qatorni o'zgartiring**:
```dart
return 'com.barakaparts.app://login-callback';  // ← Yangi nom
```

---

## ✅ QADAM 4: AndroidManifest.xml (Deep Link)

**Fayl**: `android/app/src/main/AndroidManifest.xml`

**MainActivity ichiga qo'shing** (33-qatordan keyin):
```xml
<!-- Deep Link Intent Filter -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.barakaparts.app" />
</intent-filter>
```

---

## ✅ QADAM 5: Supabase OAuth Sozlamalari

### Supabase Dashboard:
1. **Authentication → Providers → Google**
2. **Redirect URLs** ga qo'shing:
   ```
   com.barakaparts.app://login-callback
   ```

### Google Cloud Console:
1. OAuth 2.0 Credentials
2. **Authorized redirect URIs** ga qo'shing:
   ```
   com.barakaparts.app://login-callback
   ```

---

## ✅ QADAM 6: Clean va Test

```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run
```

---

## 📋 Checklist

- [ ] `android/app/build.gradle.kts` - 2 ta joy (namespace va applicationId)
- [ ] `MainActivity.kt` - package declaration va joylashuv
- [ ] `lib/core/constants/app_constants.dart` - mobileDeepLinkUrl
- [ ] `AndroidManifest.xml` - deep link intent filter
- [ ] Supabase Dashboard - OAuth redirect URLs
- [ ] Google Cloud Console - OAuth redirect URIs
- [ ] `flutter clean` va test

---

## ⚠️ MUHIM

**Yangi package nomini tanlaganingizdan keyin**, barcha joylarda bir xil nom ishlatilganini tekshiring!

**Misol**: Agar `com.barakaparts.app` tanlasangiz:
- Android: `com.barakaparts.app`
- Deep Link: `com.barakaparts.app://login-callback`
- Supabase: `com.barakaparts.app://login-callback`
- Google Cloud: `com.barakaparts.app://login-callback`

**Hammasi bir xil bo'lishi kerak!**













