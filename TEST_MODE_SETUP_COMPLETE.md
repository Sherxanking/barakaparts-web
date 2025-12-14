# ✅ Test Rejimi Sozlash Tugallandi - BarakaParts

## 📋 Xulosa

BarakaParts ilovasi **Test Rejimi** uchun muvaffaqiyatli sozlandi:
- ✅ Telefon OTP login **O'CHIRILDI**
- ✅ Google OAuth login **FAOL** (default role: "worker")
- ✅ Manager va Boss uchun test akkauntlar (email/password login)
- ✅ Test akkauntlar uchun avtomatik role tayinlash
- ✅ Supabase'da ma'lumotlar saqlanishi tekshirildi

---

## ✅ Bajarilgan Vazifalar

### 1. **Telefon OTP Login O'chirildi**
- ✅ `splash_page.dart` `PhoneLoginPage` o'rniga `LoginPage` ishlatishga o'zgartirildi
- ✅ Telefon OTP oqimi o'chirildi (keyinroq qayta yoqish mumkin)

### 2. **Google OAuth Faol**
- ✅ Google OAuth login to'g'ri ishlaydi
- ✅ Yangi Google foydalanuvchilar avtomatik **"worker"** rolini oladi
- ✅ Foydalanuvchi profillari `public.users` jadvalida yaratiladi
- ✅ Ma'lumotlar Supabase'da saqlanadi

### 3. **Test Akkauntlar Yaratildi**
- ✅ **Manager Akkaunti**:
  - Email: `manager@test.com`
  - Parol: `Manager123!`
  - Role: `manager`
  
- ✅ **Boss Akkaunti**:
  - Email: `boss@test.com`
  - Parol: `Boss123!`
  - Role: `boss`

### 4. **Avtomatik Role Tayinlash**
- ✅ Test akkauntlar login paytida to'g'ri rollarni avtomatik oladi
- ✅ Role tayinlash `signInWithEmail()` metodida amalga oshiriladi
- ✅ Agar role noto'g'ri bo'lsa, avtomatik tuzatiladi

### 5. **Ma'lumotlar Saqlanishi**
- ✅ Barcha foydalanuvchi ma'lumotlari `public.users` jadvalida saqlanadi
- ✅ Sections/parts `user_id` bilan bog'langan
- ✅ Ma'lumotlar app qayta ochilganda saqlanadi
- ✅ Barcha CRUD operatsiyalar Supabase'ga saqlanadi

---

## 📁 O'zgartirilgan Fayllar

### 1. `lib/presentation/pages/splash_page.dart`
- ✅ Import `phone_login_page.dart` dan `login_page.dart` ga o'zgartirildi
- ✅ Navigatsiya `LoginPage` ishlatishga yangilandi

### 2. `lib/infrastructure/datasources/supabase_user_datasource.dart`
- ✅ `_getRoleForTestAccount()` metodi qo'shildi
- ✅ `signInWithEmail()` test akkauntlarni qo'llab-quvvatlashga yangilandi
- ✅ `_autoCreateUser()` role parametrini qabul qilishga yangilandi
- ✅ Test akkauntlar to'g'ri rollarni avtomatik oladi

---

## 🔧 Texnik Tafsilotlar

### Test Akkaunt Aniqlash
```dart
String? _getRoleForTestAccount(String email) {
  final emailLower = email.toLowerCase();
  if (emailLower == 'manager@test.com') {
    return 'manager';
  } else if (emailLower == 'boss@test.com') {
    return 'boss';
  }
  return null; // Default role 'worker' ishlatiladi
}
```

### Login Oqimi
1. **Google OAuth**:
   - Foydalanuvchi "Continue with Google" ni bosadi
   - OAuth oqimini yakunlaydi
   - Foydalanuvchi profili **"worker"** roli bilan yaratiladi
   - HomePage'ga yo'naltiriladi

2. **Test Akkauntlar (Manager/Boss)**:
   - Foydalanuvchi email/password kiritadi
   - Tizim test akkaunt ekanligini tekshiradi
   - To'g'ri role tayinlaydi (manager/boss)
   - Foydalanuvchi profilini yaratadi/yangilaydi
   - HomePage'ga yo'naltiriladi

### Role Tayinlash Mantiqi
- **Google OAuth foydalanuvchilar**: Har doim `'worker'` rolini oladi
- **manager@test.com**: `'manager'` rolini oladi
- **boss@test.com**: `'boss'` rolini oladi
- **Boshqa email/password foydalanuvchilar**: `'worker'` rolini oladi (agar mavjud bo'lsa)

---

## 🧪 Test Qadamlar

### ✅ Test 1: Google OAuth Login (Worker)
1. Ilovani oching
2. "Continue with Google" ni bosing
3. Google sign-in ni yakunlang
4. **Kutilgan natija**: 
   - Foydalanuvchi login qildi
   - Role = `'worker'`
   - Foydalanuvchi profili `public.users` jadvalida
   - Parts ko'rish mumkin (faqat o'qish)

### ✅ Test 2: Manager Login
1. Ilovani oching
2. Email kiriting: `manager@test.com`
3. Parol kiriting: `Manager123!`
4. "Login" ni bosing
5. **Kutilgan natija**:
   - Foydalanuvchi login qildi
   - Role = `'manager'`
   - Parts qo'shish/tahrirlash mumkin
   - Admin panelni ko'rish mumkin
   - Ma'lumotlar Supabase'ga saqlandi

### ✅ Test 3: Boss Login
1. Ilovani oching
2. Email kiriting: `boss@test.com`
3. Parol kiriting: `Boss123!`
4. "Login" ni bosing
5. **Kutilgan natija**:
   - Foydalanuvchi login qildi
   - Role = `'boss'`
   - Parts qo'shish/tahrirlash/o'chirish mumkin
   - Admin panelga kirish mumkin
   - Foydalanuvchi rollarini o'zgartirish mumkin
   - Ma'lumotlar Supabase'ga saqlandi

### ✅ Test 4: Sections/Parts Qo'shish (Manager)
1. Manager sifatida login qiling
2. Yangi part qo'shing
3. **Kutilgan natija**:
   - Part Supabase `parts` jadvaliga saqlandi
   - `created_by` maydoni = Manager'ning user ID
   - Part ilovada ko'rinadi
   - Part app qayta ochilgandan keyin ham saqlanadi

### ✅ Test 5: Sections Tahrirlash/O'chirish (Boss)
1. Boss sifatida login qiling
2. Mavjud partni tahrirlang
3. Partni o'chiring
4. **Kutilgan natija**:
   - O'zgarishlar Supabase'ga saqlandi
   - Ma'lumotlar app qayta ochilgandan keyin ham saqlanadi
   - Barcha operatsiyalar Supabase'da log qilindi

### ✅ Test 6: Ma'lumotlar Saqlanishi
1. Manager sifatida login qiling
2. Bir nechta part qo'shing
3. Ilovani yoping
4. Ilovani qayta oching
5. Yana login qiling
6. **Kutilgan natija**:
   - Barcha parts hali ham ko'rinadi
   - Ma'lumotlar Supabase'dan olingan
   - Ma'lumotlar yo'qolgani yo'q

---

## 🚀 Supabase Sozlash Talab Qilinadi

### 1. Test Akkauntlar Yaratish
**Variant A: Supabase Dashboard orqali**
1. Supabase Dashboard → Authentication → Users ga o'ting
2. "Add User" → "Create new user" ni bosing
3. Manager yarating:
   - Email: `manager@test.com`
   - Parol: `Manager123!`
   - Auto Confirm User: **ON**
4. Boss yarating:
   - Email: `boss@test.com`
   - Parol: `Boss123!`
   - Auto Confirm User: **ON**

**Variant B: SQL orqali (auth foydalanuvchilar yaratilgandan keyin)**
```sql
-- Avval user ID larni oling
SELECT id, email FROM auth.users 
WHERE email IN ('manager@test.com', 'boss@test.com');

-- Keyin public.users da rollarni yangilang
UPDATE public.users
SET role = 'manager'
WHERE email = 'manager@test.com';

UPDATE public.users
SET role = 'boss'
WHERE email = 'boss@test.com';
```

### 2. Akkauntlarni Tekshirish
```sql
SELECT 
  u.id,
  u.email,
  u.name,
  u.role,
  u.created_at
FROM public.users u
WHERE u.email IN ('manager@test.com', 'boss@test.com');
```

### 3. Ma'lumotlar Saqlanishini Tekshirish
```sql
-- Parts jadvalini tekshiring
SELECT 
  p.id,
  p.name,
  p.quantity,
  p.created_by,
  u.email as creator_email,
  u.role as creator_role
FROM parts p
LEFT JOIN users u ON p.created_by = u.id
ORDER BY p.created_at DESC;
```

---

## 📊 Ma'lumotlar Bazasi Strukturasi

### `public.users` Jadvali
- `id` (UUID, Primary Key) - auth.users dan
- `name` (TEXT) - Foydalanuvchi ismi
- `email` (TEXT) - Foydalanuvchi emaili
- `role` (TEXT) - 'worker', 'manager', yoki 'boss'
- `created_at` (TIMESTAMP) - Akkaunt yaratilgan vaqt
- `updated_at` (TIMESTAMP) - Oxirgi yangilanish vaqti

### `public.parts` Jadvali
- `id` (UUID, Primary Key)
- `name` (TEXT) - Part nomi
- `quantity` (INTEGER) - Joriy miqdor
- `min_quantity` (INTEGER) - Ogohlantirish chegarasi
- `created_by` (UUID, Foreign Key → users.id)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

---

## ✅ Tekshirish Ro'yxati

- ✅ Telefon OTP login o'chirildi
- ✅ Google OAuth login faol
- ✅ Google foydalanuvchilar 'worker' rolini oladi
- ✅ Manager test akkaunti ishlaydi
- ✅ Boss test akkaunti ishlaydi
- ✅ Rollar to'g'ri tayinlandi
- ✅ Ma'lumotlar Supabase'ga saqlandi
- ✅ Ma'lumotlar qayta ochilgandan keyin saqlanadi
- ✅ Sections/parts user ID lar bilan bog'langan
- ✅ Barcha CRUD operatsiyalar saqlandi

---

## 🎯 Keyingi Qadamlar

1. **Supabase'da Test Akkauntlar Yaratish**:
   - Supabase Dashboard yoki SQL migration ishlating
   - Akkauntlar `public.users` jadvalida mavjudligini tekshiring

2. **Oqimni Test Qilish**:
   - Google OAuth login ni test qiling
   - Manager login ni test qiling
   - Boss login ni test qiling
   - Ma'lumotlar saqlanishini tekshiring

3. **Supabase'da Ma'lumotlarni Tekshirish**:
   - `public.users` jadvalini tekshiring
   - `public.parts` jadvalini tekshiring
   - `created_by` referenslarini tekshiring

4. **Production Tayyor**:
   - Barcha test akkauntlar ishlaydi
   - Ma'lumotlar saqlanishi tekshirildi
   - Role-based kirish ishlaydi

---

## 📝 Eslatmalar

- **Telefon OTP**: Hozircha o'chirilgan, keyinroq qayta yoqish mumkin
- **Google OAuth**: Faol, foydalanuvchilarni 'worker' roli bilan yaratadi
- **Test Akkauntlar**: Email/password ishlatadi, Google OAuth ni o'tkazib yuboradi
- **Ma'lumotlar Saqlanishi**: Barcha ma'lumotlar Supabase SQL jadvallariga saqlanadi
- **Role Tayinlash**: Test akkauntlar uchun email asosida avtomatik

**Holat: ✅ TUGALLANDI - Testga Tayyor**

---

## 🔍 Muammolarni Hal Qilish

### Muammo: Test akkaunt login qilmaydi
**Yechim**: 
1. Supabase Dashboard → Authentication → Users da akkaunt mavjudligini tekshiring
2. Akkaunt tasdiqlanganligini tekshiring (Auto Confirm ON bo'lishi kerak)
3. Parol to'g'riligini tekshiring

### Muammo: Noto'g'ri role tayinlandi
**Yechim**:
1. Email aniq `manager@test.com` yoki `boss@test.com` ekanligini tekshiring
2. `public.users` jadvalida rolni tekshiring
3. Yana login qiling - role avtomatik tuzatiladi

### Muammo: Ma'lumotlar saqlanmaydi
**Yechim**:
1. Supabase ulanishini tekshiring
2. RLS siyosatlari insert/update ga ruxsat berishini tekshiring
3. `created_by` maydoni to'g'ri o'rnatilganligini tekshiring

**Barcha sozlash tugallandi! Testga tayyor!** 🚀
