# 📦 Package Nomini O'zgartirish - To'liq Ko'rsatma

## 🎯 Hozirgi Holat

- **Android Package**: `com.example.parts_control`
- **iOS Bundle ID**: `com.example.partsControl`
- **Deep Link**: `com.barakaparts://login-callback`

---

## 📝 QADAM 1: Yangi Package Nomini Tanlang

**Format**: `com.yourcompany.appname`

**Misollar**:
- `com.barakaparts.app`
- `com.barakaparts.inventory`
- `com.yourcompany.barakaparts`

**⚠️ Eslatma**: 
- Kichik harflar ishlating
- Underscore (_) yoki tire (-) ishlatishingiz mumkin
- Barcha joylarda bir xil nom ishlatilishi kerak

---

## 🤖 QADAM 2: Android - build.gradle.kts

**Fayl**: `android/app/build.gradle.kts`

**O'zgartirish** (2 ta joy):

```kotlin
android {
    namespace = "com.barakaparts.app"  // ← 9-qator (o'zgartiring)
    // ...
    defaultConfig {
        applicationId = "com.barakaparts.app"  // ← 24-qator (o'zgartiring)
    }
}
```

---

## 📁 QADAM 3: Kotlin Faylini Ko'chirish

### Windows PowerShell:

```powershell
# 1. Yangi papka yaratish
New-Item -ItemType Directory -Force -Path "android\app\src\main\kotlin\com\barakaparts\app"

# 2. Faylni ko'chirish
Move-Item "android\app\src\main\kotlin\com\example\parts_control\MainActivity.kt" `
          "android\app\src\main\kotlin\com\barakaparts\app\MainActivity.kt"

# 3. Package nomini o'zgartirish
$content = Get-Content "android\app\src\main\kotlin\com\barakaparts\app\MainActivity.kt"
$content = $content -replace 'package com.example.parts_control', 'package com.barakaparts.app'
$content | Set-Content "android\app\src\main\kotlin\com\barakaparts\app\MainActivity.kt"

# 4. Eski papkani o'chirish
Remove-Item -Recurse "android\app\src\main\kotlin\com\example"
```

### Linux/Mac:

```bash
# 1. Yangi papka yaratish
mkdir -p android/app/src/main/kotlin/com/barakaparts/app

# 2. Faylni ko'chirish
mv android/app/src/main/kotlin/com/example/parts_control/MainActivity.kt \
   android/app/src/main/kotlin/com/barakaparts/app/MainActivity.kt

# 3. Package nomini o'zgartirish
sed -i 's/package com.example.parts_control/package com.barakaparts.app/g' \
    android/app/src/main/kotlin/com/barakaparts/app/MainActivity.kt

# 4. Eski papkani o'chirish
rm -rf android/app/src/main/kotlin/com/example
```

---

## 🍎 QADAM 4: iOS - Xcode Project

### Variant A: Xcode orqali (Tavsiya etiladi)

1. **Xcode'da loyihani oching**:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Runner target'ni tanlang** (chap panelda)

3. **General tab**:
   - **Bundle Identifier** ni o'zgartiring: `com.barakaparts.app`

4. **Build Settings tab**:
   - **Product Bundle Identifier** ni qidiring
   - Barcha variantlar uchun (Debug, Release, Profile) o'zgartiring: `com.barakaparts.app`

### Variant B: Qo'lda (project.pbxproj)

**Fayl**: `ios/Runner.xcodeproj/project.pbxproj`

**Barcha joylarda** `com.example.partsControl` ni `com.barakaparts.app` ga o'zgartiring:

```bash
# Linux/Mac:
sed -i 's/com.example.partsControl/com.barakaparts.app/g' ios/Runner.xcodeproj/project.pbxproj

# Windows PowerShell:
(Get-Content "ios\Runner.xcodeproj\project.pbxproj") `
  -replace 'com.example.partsControl', 'com.barakaparts.app' | `
  Set-Content "ios\Runner.xcodeproj\project.pbxproj"
```

**⚠️ Eslatma**: Bu fayl murakkab, Xcode orqali o'zgartirish yaxshiroq!

---

## 🔗 QADAM 5: Deep Link URL

**Fayl**: `lib/core/constants/app_constants.dart`

**64-qatorni o'zgartiring**:

```dart
static String get mobileDeepLinkUrl {
  return 'com.barakaparts.app://login-callback';  // ← Yangi nom
}
```

---

## 📱 QADAM 6: AndroidManifest.xml (Deep Link)

**Fayl**: `android/app/src/main/AndroidManifest.xml`

**MainActivity ichiga qo'shing** (33-qatordan keyin, `</intent-filter>` dan keyin):

```xml
<!-- Deep Link Intent Filter for OAuth -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.barakaparts.app" />
</intent-filter>
```

**To'liq ko'rinish**:
```xml
<activity
    android:name=".MainActivity"
    ...>
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    
    <!-- Deep Link Intent Filter for OAuth -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.barakaparts.app" />
    </intent-filter>
</activity>
```

---

## 🔐 QADAM 7: Supabase OAuth Sozlamalari

### 7.1. Supabase Dashboard

1. **Authentication → Providers → Google** ga kiring
2. **Redirect URLs** bo'limiga qo'shing:
   ```
   com.barakaparts.app://login-callback
   ```
3. **Save** bosing

### 7.2. Google Cloud Console

1. [Google Cloud Console](https://console.cloud.google.com/) ga kiring
2. **APIs & Services → Credentials** ga kiring
3. OAuth 2.0 Client ID ni tanlang
4. **Authorized redirect URIs** ga qo'shing:
   ```
   com.barakaparts.app://login-callback
   ```
5. **Save** bosing

---

## 🔑 QADAM 8: SHA-1 Fingerprint (Android)

Yangi package nomi bilan yangi SHA-1 olish:

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

## ✅ QADAM 9: Clean va Test

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

## 📋 Yakuniy Checklist

### Android:
- [ ] `android/app/build.gradle.kts` - namespace va applicationId
- [ ] `MainActivity.kt` - package declaration va joylashuv
- [ ] `AndroidManifest.xml` - deep link intent filter

### iOS:
- [ ] Xcode'da Bundle Identifier o'zgartirildi
- [ ] Yoki `project.pbxproj` qo'lda o'zgartirildi

### Flutter:
- [ ] `lib/core/constants/app_constants.dart` - mobileDeepLinkUrl

### External Services:
- [ ] Supabase Dashboard - OAuth redirect URLs
- [ ] Google Cloud Console - OAuth redirect URIs
- [ ] Supabase Dashboard - SHA-1 fingerprint (Android)

### Test:
- [ ] `flutter clean` bajarildi
- [ ] App ishga tushdi
- [ ] Package nomi to'g'ri (Settings → Apps → Your App)
- [ ] Google OAuth ishlaydi

---

## ⚠️ Xatolar va Yechimlar

### Xato: "Package name does not match"
**Yechim**: Barcha joylarda bir xil nom ishlatilganini tekshiring

### Xato: "MainActivity not found"
**Yechim**: Kotlin fayl to'g'ri joyda ekanligini tekshiring

### Xato: "OAuth redirect mismatch"
**Yechim**: Supabase va Google Cloud Console'da redirect URL'lar bir xil ekanligini tekshiring

### Xato: Build error
**Yechim**: 
```bash
flutter clean
cd android && ./gradlew clean && cd ..
flutter pub get
flutter run
```

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
4. Xcode'da "Clean Build Folder" qiling (Cmd+Shift+K)

---

## 📝 Fayllar Ro'yxati

O'zgartirilishi kerak bo'lgan fayllar:

1. ✅ `android/app/build.gradle.kts`
2. ✅ `android/app/src/main/kotlin/.../MainActivity.kt` (joylashuv va ichidagi package)
3. ✅ `ios/Runner.xcodeproj/project.pbxproj` (yoki Xcode orqali)
4. ✅ `lib/core/constants/app_constants.dart`
5. ✅ `android/app/src/main/AndroidManifest.xml` (deep link qo'shish)
6. ✅ Supabase Dashboard sozlamalari
7. ✅ Google Cloud Console sozlamalari

---

**Tayyor! Endi package nomingizni o'zgartirishingiz mumkin! 🚀**






