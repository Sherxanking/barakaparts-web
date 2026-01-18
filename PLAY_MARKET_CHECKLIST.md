# Play Market Release Checklist

## ✅ Tayyor bo'lgan narsalar:

1. ✅ **App Name**: BarakaParts
2. ✅ **Package Name**: com.probaraka.barakaparts
3. ✅ **Version**: 1.0.0+1 (pubspec.yaml)
4. ✅ **App Icons**: Barcha density'lar uchun mavjud (mipmap-hdpi, mdpi, xhdpi, xxhdpi, xxxhdpi)
5. ✅ **AndroidManifest.xml**: To'g'ri sozlangan
6. ✅ **Permissions**: Camera, Storage, Internet
7. ✅ **Deep Linking**: OAuth uchun sozlangan

## ❌ Qilinishi kerak bo'lgan ishlar:

### 1. **App Signing Key (MUHIM!)**

**Hozir:** Debug key ishlatilmoqda (release uchun ishlamaydi)

**Qilinishi kerak:**
```bash
# Keystore yaratish
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Keyin:**
- `android/key.properties` fayli yaratish
- Parollarni kiriting
- `build.gradle.kts` ni yangilash (signing config qo'shish)

### 2. **Version Management**

**Hozir:** 1.0.0+1

**Eslatma:** Har bir yangi release uchun:
- `versionName` o'zgartirish (1.0.1, 1.0.2, ...)
- `versionCode` oshirish (+2, +3, ...)

### 3. **Release Build Test**

```bash
# App Bundle yaratish (Play Store uchun)
flutter build appbundle --release

# APK yaratish (test uchun)
flutter build apk --release
```

**Tekshirish:**
- Real qurilmada test qilish
- Barcha funksiyalarni tekshirish
- Performance test

### 4. **ProGuard/R8 Configuration**

**Hozir:** ProGuard o'chirilgan (debug key ishlatilganda)

**Release uchun:**
- `build.gradle.kts` da `isMinifyEnabled = true` qo'yish
- `proguard-rules.pro` fayli yaratish (agar kerak bo'lsa)

### 5. **Play Store Listing**

**Kerakli ma'lumotlar:**
- [ ] App description (uzbek va ingliz tillarida)
- [ ] Short description (80 belgi)
- [ ] Full description (4000 belgi)
- [ ] Screenshots:
  - [ ] Telefon (kamida 2 ta, maksimal 8 ta)
  - [ ] Tablet (ixtiyoriy)
- [ ] Feature graphic (1024x500 px)
- [ ] App icon (512x512 px) - `ic_launcher-playstore.png` mavjud
- [ ] Privacy policy URL (agar kerak bo'lsa)
- [ ] Content rating
- [ ] App category
- [ ] Contact information

### 6. **Testing**

- [ ] Release build'ni real qurilmada test qilish
- [ ] Barcha funksiyalarni test qilish:
  - [ ] Login/Logout
  - [ ] Parts CRUD
  - [ ] Products CRUD
  - [ ] Orders CRUD
  - [ ] Departments CRUD
  - [ ] Batch add parts
  - [ ] Contact phone call
- [ ] Performance test
- [ ] Memory leak tekshirish
- [ ] Network error handling

### 7. **Security Check**

- [ ] API keys environment variable'da
- [ ] Sensitive ma'lumotlar hardcode qilinmagan
- [ ] Keystore fayli xavfsiz saqlangan
- [ ] `key.properties` Git'ga commit qilinmagan

### 8. **Other**

- [ ] Crash reporting (Firebase Crashlytics yoki boshqa) - ixtiyoriy
- [ ] Analytics (agar kerak bo'lsa) - ixtiyoriy
- [ ] Update mechanism (ota update) - ixtiyoriy

## 📋 Qadam-baqadam:

### Qadam 1: Keystore yaratish
```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Qadam 2: key.properties yaratish
`android/key.properties` faylini yaratib, parollarni kiriting.

### Qadam 3: build.gradle.kts yangilash
Signing config qo'shish (yoki hozir debug key bilan test qilish).

### Qadam 4: Release build
```bash
flutter build appbundle --release
```

### Qadam 5: Test qilish
APK'ni real qurilmada test qilish.

### Qadam 6: Play Console'ga yuklash
1. Google Play Console ga kiring
2. App yaratish yoki tanlash
3. App Bundle (.aab) yuklash
4. Listing ma'lumotlarini to'ldirish
5. Review'ga yuborish

## ⚠️ MUHIM ESLATMALAR:

1. **Keystore faylini xavfsiz saqlang!** - Uni yo'qotib qo'ysangiz, app'ni yangilab bo'lmaydi!
2. **Parolni yozib qo'ying!** - Unutib qo'ysangiz, app'ni yangilab bo'lmaydi!
3. **Backup qiling!** - Keystore faylini bir necha joyda saqlang!
4. **Git'ga commit qilmang!** - Keystore va key.properties fayllarini Git'ga qo'shmang!



