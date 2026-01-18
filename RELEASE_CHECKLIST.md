# Play Market Release Checklist

## ✅ Tayyor bo'lgan narsalar:
- [x] App name: BarakaParts
- [x] Package name: com.probaraka.barakaparts
- [x] Version: 1.0.0+1 (pubspec.yaml)
- [x] App icons (barcha density'lar uchun mavjud)
- [x] AndroidManifest.xml (permissions to'g'ri)
- [x] Deep linking (OAuth uchun)

## ❌ Qilinishi kerak bo'lgan ishlar:

### 1. App Signing (MUHIM!)
**Hozir debug key ishlatilmoqda - release uchun signing config kerak**

**Qadamlar:**
```bash
# 1. Keystore yaratish
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# 2. key.properties fayli yaratish (android/ papkasida)
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=<path-to-keystore>/upload-keystore.jks
```

**build.gradle.kts ni yangilash:**
- Signing config qo'shish
- Release build uchun signing config ishlatish

### 2. Version Management
- [x] Version name: 1.0.0 (pubspec.yaml)
- [x] Version code: 1 (pubspec.yaml)
- ⚠️ Har bir yangi release'da version code oshirish kerak

### 3. ProGuard/R8 Configuration
- Minification yoqish
- Obfuscation yoqish
- ProGuard rules qo'shish (agar kerak bo'lsa)

### 4. Release Build Test
```bash
# Release APK yaratish
flutter build apk --release

# App Bundle yaratish (Play Store uchun tavsiya etiladi)
flutter build appbundle --release
```

### 5. Play Store Listing
- [ ] App description (uzbek va ingliz tillarida)
- [ ] Screenshots (telefon va tablet uchun)
- [ ] Feature graphic (1024x500)
- [ ] Privacy policy URL
- [ ] Content rating
- [ ] App category

### 6. Testing
- [ ] Release build'ni real qurilmada test qilish
- [ ] Barcha funksiyalarni test qilish
- [ ] Performance test
- [ ] Memory leak tekshirish

### 7. Security
- [ ] API keys'lar environment variable'da
- [ ] Sensitive ma'lumotlar hardcode qilinmagan
- [ ] SSL pinning (agar kerak bo'lsa)

### 8. Permissions
- [x] Camera (image picker uchun)
- [x] Storage (image picker uchun)
- [x] Internet (Supabase uchun)
- [ ] Phone call (url_launcher uchun) - AndroidManifest.xml'ga qo'shish kerak

### 9. Other
- [ ] Crash reporting (Firebase Crashlytics yoki boshqa)
- [ ] Analytics (agar kerak bo'lsa)
- [ ] Update mechanism (ota update)

