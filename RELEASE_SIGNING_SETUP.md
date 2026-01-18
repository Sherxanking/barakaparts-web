# 🔐 Release Signing Setup - BarakaParts

## ⚠️ MUAMMO

Google Play Console xatosi:
```
Загруженный APK-файл или набор Android App Bundle был подписан в режиме отладки.
Подпишите файл или набор в режиме выпуска.
```

**Sabab**: App debug keystore bilan imzolangan, lekin release keystore kerak!

---

## ✅ YECHIM: Release Keystore Yaratish

### Qadam 1: Keystore Yaratish

PowerShell yoki Command Prompt'da quyidagi buyruqni bajaring:

```bash
cd android/app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Kiritiladigan ma'lumotlar**:
- **Keystore password**: (Parol yozing va eslab qoling!)
- **Key password**: (Xuddi shu parol yoki boshqa parol)
- **Name**: (Ismingiz yoki kompaniya nomi)
- **Organizational Unit**: (Bo'lim nomi, ixtiyoriy)
- **Organization**: (Kompaniya nomi)
- **City**: (Shahar)
- **State**: (Viloyat)
- **Country**: (Mamlakat kodi, masalan: UZ)

**⚠️ MUHIM**: 
- Parollarni **ESLAB QOLING** yoki xavfsiz joyga yozib qo'ying!
- Keystore faylini **XAVFSIZ SAQLANG**!
- Bu keystore'ni yo'qotib qo'ysangiz, app'ni yangilay olmaysiz!

---

### Qadam 2: key.properties Faylini Yaratish

`android/key.properties` faylini yarating va quyidagi ma'lumotlarni kiriting:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=app/upload-keystore.jks
```

**O'zgartirishlar**:
- `YOUR_KEYSTORE_PASSWORD` → Keystore parolingiz
- `YOUR_KEY_PASSWORD` → Key parolingiz (odatda keystore paroli bilan bir xil)

**⚠️ MUHIM**: 
- Bu fayl **Git'ga commit qilinmasligi kerak**!
- `.gitignore`'da `key.properties` va `*.jks` bo'lishi kerak!

---

### Qadam 3: .gitignore Tekshirish

`.gitignore` faylida quyidagilar bo'lishi kerak:

```
# Keystore files (DO NOT COMMIT!)
*.jks
*.keystore
key.properties
upload-keystore.jks
```

---

### Qadam 4: Release Build Qilish

Keystore yaratilgandan keyin, release build qiling:

```bash
flutter build appbundle --release
```

Yoki APK uchun:

```bash
flutter build apk --release
```

---

## 📁 Fayl Strukturasi

```
android/
├── app/
│   ├── upload-keystore.jks  ← Keystore fayli (Git'ga commit qilinmaydi!)
│   └── build.gradle.kts      ← Signing config mavjud
└── key.properties            ← Parollar (Git'ga commit qilinmaydi!)
```

---

## ✅ Tekshirish

Release build qilgandan keyin, imzolanganligini tekshiring:

```bash
# AAB uchun
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab

# APK uchun
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

Agar "jar verified" ko'rsatilsa, to'g'ri imzolangan!

---

## ⚠️ XAVFSIZLIK

### 1. Keystore Parollari
- ✅ Parollarni **hech kimga bermang**!
- ✅ Parollarni **xavfsiz joyga yozib qo'ying** (password manager)
- ✅ Keystore faylini **backup qiling** (xavfsiz joyga)

### 2. Git'ga Commit Qilmaslik
- ✅ `key.properties` → **Git'ga commit qilinmaydi**
- ✅ `upload-keystore.jks` → **Git'ga commit qilinmaydi**
- ✅ `.gitignore`'da mavjud bo'lishi kerak

### 3. Backup
- ✅ Keystore faylini **xavfsiz joyga backup qiling**
- ✅ Parollarni **yozib qo'ying**
- ✅ Agar yo'qolsa, app'ni yangilay olmaysiz!

---

## 🚀 Keyingi Qadamlar

1. ✅ Keystore yaratish
2. ✅ `key.properties` yaratish
3. ✅ Release build qilish
4. ✅ Google Play Console'ga yuklash

---

## 📞 Yordam

Agar muammo bo'lsa:
1. Keystore parolini tekshiring
2. `key.properties` faylini tekshiring
3. `build.gradle.kts`'dagi signing config'ni tekshiring
4. Build log'larini ko'rib chiqing

---

## ✅ Xulosa

**Release keystore yaratish MUTLAQ KERAK!**

Aks holda:
- ❌ Google Play Console'ga yuklab bo'lmaydi
- ❌ "Debug signing" xatosi chiqadi
- ❌ App publish qilinmaydi

**Keystore yaratish 5 daqiqa vaqt oladi!** ✅


