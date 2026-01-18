# 📱 Google Play Console - Test Account Sozlash

## ⚠️ MUHIM: Google Play Review

Google Play Console'da app qo'yilganda, Google review qiladi:
- **Internal Testing**: Odatda review yo'q, lekin ba'zida tekshiriladi
- **Closed/Open Testing**: Review bo'ladi
- **Production**: Majburiy review

Agar app **login/parol** talab qilsa, Google test qilish uchun account kerak!

---

## ✅ Hozirgi Test Accountlar

Sizning app'ingizda quyidagi test accountlar mavjud:

### 1. **Manager Account** (Test uchun)
- **Email**: `manager@test.com`
- **Parol**: `Manager123!`
- **Role**: `manager`
- **Imkoniyatlar**: Parts qo'shish/tahrirlash, Admin panel

### 2. **Boss Account** (Test uchun)
- **Email**: `boss@test.com`
- **Parol**: `Boss123!`
- **Role**: `boss`
- **Imkoniyatlar**: Barcha funksiyalar, Full access

### 3. **Worker Account** (Google OAuth orqali)
- **Login**: Google OAuth
- **Role**: `worker` (avtomatik)
- **Imkoniyatlar**: Faqat parts ko'rish

---

## 📝 Google Play Console'da Test Account Qo'yish

### Qadam 1: Play Console'ga Kirish
1. [Google Play Console](https://play.google.com/console) ga kiring
2. App'ingizni tanlang

### Qadam 2: App Content → App Access
1. Chap menudan **"Policy"** → **"App content"** ni tanlang
2. **"App access"** bo'limiga o'ting
3. **"Manage"** tugmasini bosing

### Qadam 3: Test Account Ma'lumotlarini Kiriting
1. **"Add test account"** tugmasini bosing
2. Quyidagi ma'lumotlarni kiriting:

#### Test Account 1: Manager
```
Email: manager@test.com
Password: Manager123!
Notes: Manager role - can add/edit parts, access admin panel
```

#### Test Account 2: Boss
```
Email: boss@test.com
Password: Boss123!
Notes: Boss role - full access to all features
```

### Qadam 4: Saqlash
1. **"Save"** tugmasini bosing
2. Test accountlar saqlanadi

---

## 🎯 Review Jarayonida

Google review qilganda:
1. App'ni yuklab oladi
2. Test account bilan login qiladi
3. Asosiy funksiyalarni tekshiradi:
   - Login ishlashi
   - Parts ko'rish/qo'shish
   - Orders yaratish
   - Navigation ishlashi
   - Crash yo'qligi

---

## ⚠️ Eslatmalar

### 1. **Test Accountlar Xavfsizligi**
- ✅ Test accountlar faqat review uchun
- ✅ Production'da test accountlar o'chirilishi mumkin (lekin kerak emas)
- ✅ Test accountlar oddiy foydalanuvchilar ko'rmaydi

### 2. **Email Verification**
- ✅ Test accountlar (`manager@test.com`, `boss@test.com`) email verification bypass qiladi
- ✅ Boshqa foydalanuvchilar uchun email verification talab qilinadi

### 3. **Review Vaqti**
- **Internal Testing**: 1-2 kun
- **Closed/Open Testing**: 2-7 kun
- **Production**: 1-7 kun (odatda 1-3 kun)

---

## 🚀 Tavsiyalar

### 1. **Test Account Yaratish**
- ✅ Google Play Console'da test account qo'ying
- ✅ Har bir role uchun alohida account (Manager, Boss)
- ✅ Parollar oddiy va tushunarli bo'lsin

### 2. **Review Notes Qo'shish**
Google Play Console'da **"Review notes"** bo'limiga quyidagilarni yozing:

```
Test Account Information:
- Manager: manager@test.com / Manager123!
- Boss: boss@test.com / Boss123!

App Features:
- Parts inventory management
- Orders creation and tracking
- Department management
- Role-based access control (Worker, Manager, Boss)

Please use Manager or Boss account for full feature testing.
```

### 3. **Demo Mode (Ixtiyoriy)**
Agar xohlasangiz, demo mode qo'shish mumkin:
- Login sahifasida **"Try Demo"** tugmasi
- Demo account bilan avtomatik login
- Faqat ko'rish rejimi (CRUD yo'q)

---

## ✅ Checklist

Google Play Console'ga qo'yishdan oldin:

- [ ] Test accountlar Google Play Console'da qo'shilgan
- [ ] Test account parollari to'g'ri
- [ ] Review notes yozilgan
- [ ] App'da test accountlar ishlayapti
- [ ] Login sahifasi to'g'ri ishlayapti
- [ ] Barcha funksiyalar test account bilan ishlayapti

---

## 📞 Yordam

Agar Google review'da muammo bo'lsa:
1. **Review notes** ni tekshiring
2. **Test account** ma'lumotlarini qayta tekshiring
3. **App'ni o'zingiz test qiling** - test account bilan
4. **Google Support** ga murojaat qiling

---

## 🎯 Xulosa

**Google Play Console'da test account qo'yish MUTLAQ KERAK!**

Aks holda:
- ❌ Google test qila olmaydi
- ❌ Review reject bo'lishi mumkin
- ❌ App qabul qilinmaydi

**Test account qo'yish 5 daqiqa vaqt oladi, lekin review'ni tezlashtiradi!** ✅


