# Play Market Release Instructions

## 1. Keystore yaratish (BIRINCHI QADAM - MUHIM!)

```bash
# Terminal'da quyidagi buyruqni bajaring:
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Sizdan quyidagilar so'raladi:
# - Parol (storePassword va keyPassword - bir xil bo'lishi mumkin)
# - Ism, tashkilot, shahar, davlat va hokazo
```

**Eslatma:** 
- Keystore faylini xavfsiz joyda saqlang!
- Parolni yozib qo'ying - uni unutib qo'ysangiz, app'ni yangilab bo'lmaydi!
- Keystore faylini backup qiling!

## 2. key.properties fayli yaratish

```bash
# android/ papkasida key.properties fayli yaratish
cd android
cp key.properties.example key.properties
```

Keyin `key.properties` faylini ochib, haqiqiy qiymatlarni kiriting:

```properties
storePassword=your-actual-store-password
keyPassword=your-actual-key-password
keyAlias=upload
storeFile=../upload-keystore.jks
```

## 3. Release Build yaratish

### App Bundle (Play Store uchun tavsiya etiladi):
```bash
flutter build appbundle --release
```

Fayl: `build/app/outputs/bundle/release/app-release.aab`

### APK (test uchun):
```bash
flutter build apk --release
```

Fayl: `build/app/outputs/flutter-apk/app-release.apk`

## 4. Test qilish

Release build'ni real qurilmada test qiling:
```bash
# APK'ni telefon'ga o'rnatish
flutter install --release
```

Yoki APK'ni to'g'ridan-to'g'ri telefon'ga o'tkazing va o'rnating.

## 5. Play Console'ga yuklash

1. [Google Play Console](https://play.google.com/console) ga kiring
2. Yangi app yaratish yoki mavjud app'ni tanlash
3. "Production" yoki "Internal testing" track'ni tanlash
4. App Bundle (.aab) faylini yuklash
5. App listing ma'lumotlarini to'ldirish:
   - App description
   - Screenshots
   - Feature graphic
   - Privacy policy URL
   - Content rating
6. Review'ga yuborish

## 6. Version yangilash

Har bir yangi release uchun `pubspec.yaml` faylida version o'zgartirish:

```yaml
version: 1.0.1+2  # versionName+versionCode
```

- `versionName` (1.0.1) - foydalanuvchilar ko'radigan versiya
- `versionCode` (+2) - har safar oshirish kerak (1, 2, 3, ...)

## 7. Xavfsizlik eslatmalari

- ✅ Keystore faylini Git'ga commit qilmang (`.gitignore` da mavjud)
- ✅ `key.properties` faylini Git'ga commit qilmang
- ✅ API keys'lar environment variable'da
- ✅ Sensitive ma'lumotlar hardcode qilinmagan

## 8. Muammo hal qilish

### Build xatolik:
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Signing xatolik:
- `key.properties` fayli to'g'ri joyda ekanligini tekshiring (android/ papkasida)
- Keystore fayli to'g'ri yo'lda ekanligini tekshiring
- Parollar to'g'ri ekanligini tekshiring

### ProGuard xatolik:
- `proguard-rules.pro` faylini tekshiring
- Agar muammo bo'lsa, `isMinifyEnabled = false` qilib test qiling



