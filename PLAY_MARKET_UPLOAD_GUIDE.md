# 📱 Google Play Market'ga App Yuklash - To'liq Qo'llanma

## ✅ TAYYORLIK TEKSHIRISH

### 1. Release Build Tayyorligi

- [x] ✅ Keystore yaratilgan (`upload-keystore.jks`)
- [x] ✅ `key.properties` yaratilgan
- [x] ✅ Release build qilingan (`app-release.aab`)
- [ ] ⚠️ Release build test qilingan (real device'da)

### 2. Play Console Sozlash

- [ ] ⚠️ App listing yaratilgan
- [ ] ⚠️ Screenshots yuklangan
- [ ] ⚠️ App tavsifi yozilgan
- [ ] ⚠️ Privacy Policy URL qo'shilgan
- [ ] ⚠️ Data Safety form to'ldirilgan
- [ ] ⚠️ Content rating to'ldirilgan

---

## 🚀 QADAM-BAQADAM YUKLASH

### QADAM 1: Release Build Qilish

```bash
cd E:\BarakaParts
flutter build appbundle --release
```

**Natija:** `build/app/outputs/bundle/release/app-release.aab`

**⚠️ MUHIM:** AAB fayl yaratilganini tekshiring!

---

### QADAM 2: Release Build Test Qilish

**APK yaratish (test uchun):**
```bash
flutter build apk --release
```

**Real device'da test qilish:**
- [ ] Login/Auth ishlayaptimi?
- [ ] Parts CRUD ishlayaptimi?
- [ ] Products CRUD ishlayaptimi?
- [ ] Orders ishlayaptimi?
- [ ] Departments ishlayaptimi?
- [ ] Realtime updates ishlayaptimi?
- [ ] Offline mode ishlayaptimi?
- [ ] Crash yo'qligi?

---

### QADAM 3: Google Play Console'ga Kirish

1. **Google Play Console'ga kiring**: https://play.google.com/console
2. **App yarating** (yoki mavjud app'ni tanlang)
3. **"Create app"** tugmasini bosing

---

### QADAM 4: App Asosiy Ma'lumotlari

**Kiritiladigan ma'lumotlar:**

1. **App name**: `BarakaParts` (yoki `Baraka Parts`)
2. **Default language**: `Uzbek` (yoki `English`)
3. **App or game**: `App`
4. **Free or paid**: `Free`
5. **Declarations**: 
   - ✅ Privacy Policy
   - ✅ US export laws
   - ✅ Content rating

**"Create app" tugmasini bosing**

---

### QADAM 5: App Bundle Yuklash

1. **Chap menudan "Production"** (yoki "Internal testing") ni tanlang
2. **"Create new release"** tugmasini bosing
3. **"Upload"** bo'limida:
   - **"Upload"** tugmasini bosing
   - `app-release.aab` faylini tanlang
   - Yuklash jarayoni tugaguncha kuting

**⚠️ MUHIM:** 
- AAB fayl yuklash kerak (APK emas!)
- Yuklash 5-10 daqiqa vaqt olishi mumkin

---

### QADAM 6: Release Notes

**Release notes yozish:**

```
Version 1.0.0 - Initial Release

- Ehtiyot qismlari inventarini boshqarish
- Buyurtmalar yaratish va kuzatish
- Bo'limlar boshqaruvi
- Real-time yangilanishlar
- Offline mode qo'llab-quvvatlash
- Role-based access control (Worker, Manager, Boss)
```

**"Save" tugmasini bosing**

---

### QADAM 7: App Listing Sozlash

**"Store presence" → "Main store listing"**

#### Qisqa tavsif (80 belgi):
```
Zavod ehtiyot qismlari inventarini boshqarish va buyurtmalarni kuzatish uchun professional ilova.
```

#### To'liq tavsif (4000 belgi):
```
BarakaParts - zavod va ishlab chiqarish korxonalari uchun ehtiyot qismlari inventarini boshqarish va buyurtmalarni kuzatish uchun professional mobil ilova.

🎯 ASOSIY FUNKSIYALAR:

📦 EHTIYOT QISMLARI BOSHQARUVI
• Barcha ehtiyot qismlarini ko'rish va qidirish
• Yangi qismlar qo'shish va tahrirlash
• Qismlar sonini kuzatish va yangilash
• Qismlar ma'lumotlarini batafsil ko'rish

📋 BUYURTMALAR BOSHQARUVI
• Yangi buyurtmalar yaratish
• Buyurtmalar holatini kuzatish
• Buyurtmalar tarixini ko'rish
• Buyurtmalarni tahrirlash va boshqarish

👥 BO'LIMLAR BOSHQARUVI
• Bo'limlar ro'yxatini ko'rish
• Bo'limlar bo'yicha qismlarni filtrlash
• Bo'limlar ma'lumotlarini boshqarish

🔐 XAVFSIZLIK VA RUXSATLAR
• Role-based access control (RBAC)
• Worker, Manager, Boss rollari
• Har bir rol uchun alohida ruxsatlar
• Xavfsiz autentifikatsiya

⚡ REAL-TIME YANGILANISHLAR
• Real-time ma'lumotlar yangilanishi
• Avtomatik sinxronizatsiya
• Offline rejimda ishlash imkoniyati
• Cloud-based ma'lumotlar saqlash

📊 QULAYLIKLAR
• Zamonaviy va sodda interfeys
• Tez va samarali ishlash
• Qidiruv va filtrlash funksiyalari

🏭 KIMLAR UCHUN:
• Zavodlar va ishlab chiqarish korxonalari
• Ehtiyot qismlari omborlari
• Logistika va ta'minot bo'limlari
• Inventar boshqaruvi bo'limlari

BarakaParts ilovasi sizning ehtiyot qismlari inventaringizni professional darajada boshqarishga yordam beradi.

Versiya: 1.0.0
```

---

### QADAM 8: Screenshots Yuklash

**"Store presence" → "Graphics"**

**Telefon uchun (min 2 ta):**
- [ ] Login sahifasi
- [ ] Parts ro'yxati
- [ ] Buyurtmalar sahifasi
- [ ] Settings sahifasi

**Feature graphic (1024x500 px):**
- App nomi va asosiy funksiyalar

**App icon (512x512 px):**
- App logotipi

---

### QADAM 9: Privacy Policy URL

**"Policy" → "App content" → "Privacy Policy"**

**URL kiriting:**
```
https://yourusername.github.io/repo-name/privacy-policy.html
```

Yoki web saytingiz bo'lsa:
```
https://yourwebsite.com/privacy-policy
```

---

### QADAM 10: Data Safety Form

**"Policy" → "Data safety"**

**Quyidagilarni to'ldiring:**

1. **"Does your app collect or share user data?"** → **ДА (Ha)**

2. **Data Types:**
   - ✅ Email address → Yig'iladi, Supabase'ga uzatiladi
   - ✅ Name → Yig'iladi, Supabase'ga uzatiladi
   - ✅ Phone number → Yig'iladi (ixtiyoriy), Supabase'ga uzatiladi
   - ✅ User ID → Yig'iladi, Supabase'ga uzatiladi
   - ✅ App interactions → Yig'iladi, Supabase'ga uzatiladi

3. **Data Security:**
   - ✅ Is this data encrypted in transit? → **ДА (HTTPS)**
   - ✅ Can users delete this data? → **ДА (Account o'chirish)**

4. **Data Sharing:**
   - ✅ Is this data shared with third parties? → **ДА**
   - Third-party: **Supabase** (Backend service)

5. **Error Reports / Diagnostics:**
   - ❌ **НЕТ (Yo'q)** - App error reports yig'ishmaydi

---

### QADAM 11: Content Rating

**"Policy" → "App content" → "Content rating"**

1. **"Start questionnaire"** tugmasini bosing
2. **Savollarga javob bering:**
   - App category: **Productivity / Business**
   - Violence: **No**
   - Sexual content: **No**
   - Profanity: **No**
   - Alcohol/Drugs: **No**
   - Gambling: **No**
   - Location sharing: **No**
   - User-generated content: **No**

3. **Rating olasiz:** **Everyone** (3+)

---

### QADAM 12: Test Accountlar (Agar kerak bo'lsa)

**"Policy" → "App content" → "App access"**

**Test accountlar qo'shing:**

1. **"Add test account"** tugmasini bosing
2. **Manager account:**
   - Email: `manager@test.com`
   - Password: `Manager123!`
   - Notes: Manager role - full access

3. **Boss account:**
   - Email: `boss@test.com`
   - Password: `Boss123!`
   - Notes: Boss role - full access

---

### QADAM 13: Release Review

**"Production" → "Review"**

1. **Barcha bo'limlar to'ldirilganini tekshiring:**
   - ✅ App bundle yuklangan
   - ✅ Release notes yozilgan
   - ✅ App listing to'ldirilgan
   - ✅ Screenshots yuklangan
   - ✅ Privacy Policy URL qo'shilgan
   - ✅ Data Safety form to'ldirilgan
   - ✅ Content rating to'ldirilgan

2. **"Start rollout to Production"** tugmasini bosing

---

### QADAM 14: Review Jarayoni

**Google review qiladi:**
- ⏱️ **Vaqt:** 1-7 kun (odatda 1-3 kun)
- 📧 **Email:** Review natijasi email'ga keladi
- ✅ **Qabul qilinsa:** App Play Store'da ko'rinadi
- ❌ **Reject bo'lsa:** Xatoliklar tushuntiriladi

---

## 📋 CHECKLIST

### Build
- [ ] Release AAB yaratildi
- [ ] Release APK test qilindi (real device)
- [ ] Barcha funksiyalar ishlayapti
- [ ] Crash yo'qligi

### Play Console
- [ ] App yaratildi
- [ ] App bundle yuklandi
- [ ] Release notes yozildi
- [ ] App listing to'ldirilgan
- [ ] Screenshots yuklandi
- [ ] Privacy Policy URL qo'shildi
- [ ] Data Safety form to'ldirilgan
- [ ] Content rating to'ldirilgan
- [ ] Test accountlar qo'shildi (agar kerak)
- [ ] Review'ga yuborildi

---

## ⚠️ MUHIM ESLATMALAR

1. **AAB fayl yuklash kerak** - APK emas!
2. **Release build test qilish** - Real device'da test qiling!
3. **Privacy Policy URL** - Majburiy!
4. **Data Safety form** - To'liq to'ldirish kerak!
5. **Review vaqti** - 1-7 kun (sabr qiling!)

---

## 🎯 XULOSA

**Endi qilish kerak:**

1. ✅ Release build qilish: `flutter build appbundle --release`
2. ✅ Release build test qilish (real device)
3. ✅ Google Play Console'ga kirish
4. ✅ App yaratish
5. ✅ App bundle yuklash
6. ✅ Barcha ma'lumotlarni to'ldirish
7. ✅ Review'ga yuborish

**Tayyor!** 🚀


