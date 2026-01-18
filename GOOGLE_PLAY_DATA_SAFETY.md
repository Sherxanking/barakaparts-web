# 📱 Google Play Console - Data Safety Sozlash

## ❓ Savol: "Ваше приложение собирает пользовательские данные или передает их третьим лицам?"

**Javob: ДА (Ha)**

---

## 📊 Yig'iladigan Ma'lumotlar

### 1. **Personal Information (Shaxsiy Ma'lumotlar)**

#### ✅ Email Address
- **Nima yig'iladi**: Foydalanuvchi email manzili
- **Nima uchun**: Authentication (kirish) va foydalanuvchi profilini yaratish
- **Qayerda saqlanadi**: Supabase (cloud database)
- **Uchinchi tomonlarga uzatiladimi**: Ha - Supabase (backend service)
- **Majburiymi**: Ha (authentication uchun zarur)

#### ✅ Name (Ism)
- **Nima yig'iladi**: Foydalanuvchi ismi
- **Nima uchun**: Foydalanuvchi profilini ko'rsatish
- **Qayerda saqlanadi**: Supabase (cloud database)
- **Uchinchi tomonlarga uzatiladimi**: Ha - Supabase (backend service)
- **Majburiymi**: Ha

#### ⚠️ Phone Number (Telefon raqami)
- **Nima yig'iladi**: Telefon raqami (ixtiyoriy)
- **Nima uchun**: Foydalanuvchi profilida ko'rsatish
- **Qayerda saqlanadi**: Supabase (cloud database)
- **Uchinchi tomonlarga uzatiladimi**: Ha - Supabase (backend service)
- **Majburiymi**: Yo'q (ixtiyoriy)

#### ✅ Password (Parol)
- **Nima yig'iladi**: Parol (hash qilingan holda)
- **Nima uchun**: Authentication (kirish)
- **Qayerda saqlanadi**: Supabase Auth (xavfsiz hash qilingan)
- **Uchinchi tomonlarga uzatiladimi**: Ha - Supabase Auth
- **Majburiymi**: Ha (authentication uchun zarur)

---

### 2. **App Activity (Ilova Faoliyati)**

#### ✅ App Interactions (Ilova o'zaro ta'siri)
- **Nima yig'iladi**: Foydalanuvchi harakatlari (parts qo'shish, buyurtmalar yaratish)
- **Nima uchun**: App funksiyalarini ishlatish
- **Qayerda saqlanadi**: Supabase (cloud database)
- **Uchinchi tomonlarga uzatiladimi**: Ha - Supabase
- **Majburiymi**: Ha (app ishlashi uchun zarur)

---

### 3. **Device or Other IDs (Qurilma ID)**

#### ✅ User ID (Foydalanuvchi ID)
- **Nima yig'iladi**: Unique user identifier
- **Nima uchun**: Foydalanuvchi ma'lumotlarini bog'lash
- **Qayerda saqlanadi**: Supabase (cloud database)
- **Uchinchi tomonlarga uzatiladimi**: Ha - Supabase
- **Majburiymi**: Ha (app ishlashi uchun zarur)

---

## 🔐 Data Security (Ma'lumotlar Xavfsizligi)

### Encryption (Shifrlash)
- ✅ **Data in transit**: HTTPS orqali shifrlangan
- ✅ **Data at rest**: Supabase'da shifrlangan
- ✅ **Passwords**: Hash qilingan (bcrypt)

### Data Sharing (Ma'lumotlar Ulashish)
- ✅ **Third-party service**: Supabase (backend-as-a-service)
- ⚠️ **Purpose**: App funksiyalarini ta'minlash (database, authentication)
- ✅ **Data retention**: Foydalanuvchi account o'chirilguncha saqlanadi

---

## 📝 Google Play Console'da Qanday Sozlash

### Step 1: "Does your app collect or share any of the following user data types?"
**Javob: ДА (Ha)**

### Step 2: Data Types (Ma'lumot Turlari)

#### ✅ Personal Information
- **Email address**: ✅ Yig'iladi
  - Purpose: App functionality, Authentication
  - Shared: Yes (Supabase)
  - Required: Yes
  
- **Name**: ✅ Yig'iladi
  - Purpose: App functionality
  - Shared: Yes (Supabase)
  - Required: Yes
  
- **Phone number**: ⚠️ Yig'iladi (ixtiyoriy)
  - Purpose: App functionality
  - Shared: Yes (Supabase)
  - Required: No

#### ✅ App Activity
- **App interactions**: ✅ Yig'iladi
  - Purpose: App functionality
  - Shared: Yes (Supabase)
  - Required: Yes

#### ✅ Device or Other IDs
- **User ID**: ✅ Yig'iladi
  - Purpose: App functionality
  - Shared: Yes (Supabase)
  - Required: Yes

---

### Step 3: Data Security

#### ✅ Is this data encrypted in transit?
**Javob: ДА (Ha)** - HTTPS orqali

#### ✅ Can users request that you delete this data?
**Javob: ДА (Ha)** - Account o'chirish orqali

---

### Step 4: Data Sharing

#### ✅ Is this data shared with third parties?
**Javob: ДА (Ha)**

#### Third-party service:
- **Name**: Supabase
- **Purpose**: Backend service (database, authentication)
- **Data types**: Email, Name, Phone, User ID, App interactions

---

## 📋 Qisqa Javob (Google Play Console uchun)

### "Does your app collect or share user data?"
**ДАН (Ha)**

### Collected Data Types:
1. ✅ **Email address** - Authentication uchun
2. ✅ **Name** - User profile uchun
3. ⚠️ **Phone number** - Ixtiyoriy
4. ✅ **User ID** - App funksiyalari uchun
5. ✅ **App interactions** - App funksiyalari uchun

### Data Sharing:
- ✅ **Shared with**: Supabase (backend service)
- ✅ **Purpose**: App funksiyalarini ta'minlash
- ✅ **Encrypted**: Ha (HTTPS)

### Data Security:
- ✅ **Encryption in transit**: Ha
- ✅ **User can delete data**: Ha (account o'chirish orqali)

---

## ⚠️ MUHIM Eslatmalar

1. **Password**: Parol to'g'ridan-to'g'ri saqlanmaydi - faqat hash qilingan holda Supabase Auth'da
2. **Supabase**: Trusted third-party service (GDPR compliant)
3. **Data retention**: Foydalanuvchi account o'chirilguncha saqlanadi
4. **No analytics**: App analytics yig'ilmaydi (Firebase Analytics yo'q)
5. **No ads**: Reklama yo'q, shuning uchun reklama ma'lumotlari yig'ilmaydi

---

## ✅ Checklist

- [ ] "Does your app collect or share user data?" → ДА
- [ ] Email address → Yig'iladi, Supabase'ga uzatiladi
- [ ] Name → Yig'iladi, Supabase'ga uzatiladi
- [ ] Phone number → Yig'iladi (ixtiyoriy), Supabase'ga uzatiladi
- [ ] User ID → Yig'iladi, Supabase'ga uzatiladi
- [ ] App interactions → Yig'iladi, Supabase'ga uzatiladi
- [ ] Data encrypted in transit → ДА
- [ ] Data shared with third parties → ДА (Supabase)
- [ ] Users can delete data → ДА

---

## 📞 Yordam

Agar qo'shimcha savollar bo'lsa:
1. Supabase Privacy Policy: https://supabase.com/privacy
2. Supabase Terms: https://supabase.com/terms
3. Google Play Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469


