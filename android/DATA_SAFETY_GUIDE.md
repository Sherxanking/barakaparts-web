# Google Play Console - Data Safety Bo'limini To'ldirish Qo'llanmasi

Ushbu qo'llanma BarakaParts ilovasi uchun Google Play Console'dagi Data Safety bo'limini to'ldirishga yordam beradi.

## 1. Data Collection va Sharing

### Data Collection: **HA** (Yes)
Ilova ma'lumotlar to'playdi.

### Data Sharing: **HA** (Yes) yoki **YO'Q** (No)
- Agar Supabase yoki boshqa uchinchi tomon xizmatlari ishlatilsa: **HA**
- Agar barcha ma'lumotlar faqat sizning serveringizda saqlansa: **YO'Q**

## 2. To'planadigan Ma'lumotlar Turlari

Quyidagi ma'lumotlar to'planadi deb belgilang:

### ✅ Personal info (Shaxsiy ma'lumotlar)
- **Name (Ism):** ✅ Collected (To'planadi)
  - Purpose: App functionality, Account management
  - Optional: Yes
  
- **Email address:** ✅ Collected
  - Purpose: App functionality, Account management, Authentication
  - Optional: No (required for account)

### ✅ Photos and videos (Rasmlar va videolar)
- **Photos:** ✅ Collected
  - Purpose: App functionality
  - Optional: Yes
  - Ephemeral: No (stored)

### ✅ Device or other IDs (Qurilma ID)
- **Device ID:** ✅ Collected
  - Purpose: Analytics, App functionality, Fraud prevention
  - Optional: Yes

## 3. Data Usage (Ma'lumotlardan Foydalanish)

Quyidagi maqsadlarni belgilang:

- ✅ **App functionality** - Ilovaning asosiy funksiyalari
- ✅ **Account management** - Hisobni boshqarish
- ✅ **Authentication** - Autentifikatsiya
- ✅ **Analytics** - Tahlil (agar analytics ishlatilsa)
- ✅ **Fraud prevention, security, and compliance** - Xavfsizlik
- ❌ **Advertising or marketing** - Reklama (agar ishlatilmasa)
- ❌ **Personalization** - Shaxsiylashtirish (agar ishlatilmasa)

## 4. Data Sharing (Ma'lumotlarni Baham Ko'rish)

Agar uchinchi tomon xizmatlari ishlatilsa:

### Supabase (agar ishlatilsa)
- **Service provider:** Supabase
- **Data types shared:** Personal info, Photos
- **Purpose:** App functionality, Authentication

### OAuth Providers (Google, Apple)
- **Service provider:** Google/Apple
- **Data types shared:** Email, Name
- **Purpose:** Authentication

## 5. Security Practices (Xavfsizlik Amaliyotlari)

Quyidagilarni belgilang:

- ✅ **Data is encrypted in transit** - Ma'lumotlar uzatilayotganda shifrlanadi (HTTPS)
- ✅ **Users can request data deletion** - Foydalanuvchilar ma'lumotlarni o'chirishni so'rashlari mumkin
- ✅ **Data is encrypted at rest** - Ma'lumotlar saqlanayotganda shifrlanadi

## 6. Data Deletion (Ma'lumotlarni O'chirish)

- **Users can request deletion:** ✅ Yes
- **How to request:** Email or in-app support
- **Deletion time:** Within 30 days

## 7. Privacy Policy URL

Privacy Policy URL manzilini kiriting:
- Agar veb-saytingiz bo'lsa: `https://probaraka.com/privacy-policy`
- Yoki GitHub Pages: `https://yourusername.github.io/barakaparts/privacy-policy`
- Yoki boshqa hosting xizmati

**Muhim:** Privacy Policy onlayn mavjud bo'lishi kerak va Google Play Console'da URL ko'rsatilishi kerak.

## 8. Qo'shimcha Ma'lumotlar

### Age Restrictions (Yosh Cheklovlari)
- **Target age:** 13+ (13 yoshdan yuqori)

### Data Collection Purpose (Ma'lumot To'plash Maqsadi)
Barcha ma'lumotlar faqat ilovaning asosiy funksiyalarini ta'minlash uchun to'planadi.

## 9. Tekshiruv Ro'yxati

Play Console'da to'ldirishdan oldin tekshiring:

- [ ] Barcha to'planadigan ma'lumotlar turlari belgilangan
- [ ] Ma'lumotlardan foydalanish maqsadlari ko'rsatilgan
- [ ] Uchinchi tomon xizmatlari (agar bor bo'lsa) ko'rsatilgan
- [ ] Xavfsizlik amaliyotlari belgilangan
- [ ] Privacy Policy URL kiritilgan va ishlaydi
- [ ] Barcha ma'lumotlar to'g'ri va aniq

## 10. Yordam

Agar savollar bo'lsa:
- Google Play Console yordam: https://support.google.com/googleplay/android-developer
- Privacy Policy shablon: `PRIVACY_POLICY.md` faylida

---

## O'zbek tilida qisqacha ko'rsatma:

1. **Play Console** → **Ilovangiz** → **Policy** → **Data safety**
2. **Data collection:** HA deb belgilang
3. Quyidagi ma'lumotlarni belgilang:
   - Name (Ism) - To'planadi
   - Email - To'planadi
   - Photos - To'planadi
   - Device ID - To'planadi
4. **Purpose:** App functionality, Account management, Authentication
5. **Privacy Policy URL:** Kiriting
6. **Save** tugmasini bosing
