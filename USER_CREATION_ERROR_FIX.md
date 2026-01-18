# ✅ USER CREATION ERROR FIX

**Muammo:** "Failed to create user: Database error creating new user"

**Sabab:** Trigger `handle_new_user()` RLS siyosatlarini o'tkazib yuborishga ruxsat berilmagan yoki trigger ishlamayapti.

---

## 🔍 Muammo Tahlili

"Database error creating new user" xatosi quyidagi sabablarga ko'ra yuzaga kelishi mumkin:

1. **RLS siyosati muammosi** - Trigger `public.users` ga yozishga ruxsat berilmaydi
2. **Trigger ishlamayapti** - `handle_new_user()` trigger'i mavjud emas yoki to'g'ri ishlamayapti
3. **Permission muammosi** - Trigger SECURITY DEFINER bilan yaratilmagan

---

## ✅ Yechim

### STEP 1: Trigger'ni Tekshirish va Tuzatish

**Fayl:** `supabase/migrations/012_fix_trigger_rls_bypass.sql`

Bu migratsiya:
- ✅ Trigger'ni `SECURITY DEFINER` bilan yaratadi
- ✅ RLS'ni o'tkazib yuboradi
- ✅ Xavfsiz error handling qo'shadi

**Qo'llash:**
```sql
-- Supabase Dashboard → SQL Editor da bajarish:
-- supabase/migrations/012_fix_trigger_rls_bypass.sql
```

---

### STEP 2: Xatolik Xabarlarini Yaxshilash

**Fayl:** `lib/infrastructure/datasources/supabase_user_datasource.dart`

**O'zgarishlar:**
- ✅ `PostgrestException` import qo'shildi
- ✅ Aniq xatolik xabarlari qo'shildi
- ✅ RLS muammosi uchun maxsus xabar

**Kod:**
```dart
} on PostgrestException catch (e) {
  if (e.message.contains('permission denied') || e.message.contains('row-level security')) {
    return Left<Failure, domain.User>(ServerFailure(
      'Database error: Permission denied. Check RLS policies for users table. '
      'Make sure trigger handle_new_user() has SECURITY DEFINER.'
    ));
  }
  // ... boshqa xatoliklar
}
```

---

## 🧪 Test Qilish

### 1. Trigger'ni Tekshirish

```sql
-- Supabase SQL Editor da:
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgname = 'on_auth_user_created';
```

**Kutilgan natija:**
- Trigger mavjud bo'lishi kerak
- Function `handle_new_user` bo'lishi kerak

---

### 2. Function'ni Tekshirish

```sql
-- Function SECURITY DEFINER ekanligini tekshirish:
SELECT 
  proname,
  prosecdef as is_security_definer
FROM pg_proc
WHERE proname = 'handle_new_user';
```

**Kutilgan natija:**
- `is_security_definer = true` bo'lishi kerak

---

### 3. RLS Siyosatlarini Tekshirish

```sql
-- Users jadvali uchun INSERT siyosatini tekshirish:
SELECT 
  policyname,
  cmd as command,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies
WHERE tablename = 'users' AND cmd = 'INSERT';
```

**Kutilgan natija:**
- "Users can insert own data" siyosati mavjud bo'lishi kerak
- `WITH CHECK (auth.uid() = id)` bo'lishi kerak

---

### 4. Test User Yaratish

**Flutter app'da:**
1. Admin panel orqali yangi user yaratishga urinib ko'ring
2. Xatolik xabari aniq ko'rsatilishi kerak
3. Agar RLS muammosi bo'lsa, maxsus xabar ko'rsatiladi

---

## 📋 Qo'llash Qadamlari

### 1. Supabase Migratsiyasini Qo'llash

```bash
# Supabase Dashboard → SQL Editor
# supabase/migrations/012_fix_trigger_rls_bypass.sql faylini oching
# Va barcha SQL kodini bajarish
```

### 2. Flutter Kodini Yangilash

```bash
flutter clean
flutter pub get
flutter run
```

---

## 🔍 Debug Qilish

Agar muammo davom etsa:

### 1. Trigger Log'larini Tekshirish

```sql
-- Trigger ishlayotganini tekshirish:
SELECT * FROM pg_stat_user_functions 
WHERE funcname = 'handle_new_user';
```

### 2. Manual Test

```sql
-- Test user yaratish (auth.users ga):
-- Bu Supabase Dashboard orqali qilinadi
-- Keyin trigger ishlashini kuzatish:

SELECT * FROM public.users 
WHERE email = 'test@example.com';
```

### 3. RLS'ni Vaqtinchalik O'chirish (Test Uchun)

```sql
-- ⚠️ FAQAT TEST UCHUN!
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Test qiling
-- Keyin qayta yoqing:
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

---

## ✅ Kutilgan Natija

Muammo tuzatilgandan keyin:

1. ✅ Yangi foydalanuvchi yaratish ishlaydi
2. ✅ Trigger avtomatik `public.users` ga yozadi
3. ✅ Xatolik xabarlari aniq ko'rsatiladi
4. ✅ RLS xavfsizlik saqlanadi

---

## 📝 Xulosa

**Asosiy muammo:** Trigger RLS'ni o'tkazib yuborishga ruxsat berilmagan.

**Yechim:**
1. ✅ Trigger'ni `SECURITY DEFINER` bilan yaratish
2. ✅ Aniq xatolik xabarlari
3. ✅ RLS siyosatlarini to'g'ri sozlash

**Fayllar:**
- `supabase/migrations/012_fix_trigger_rls_bypass.sql` - Trigger fix
- `lib/infrastructure/datasources/supabase_user_datasource.dart` - Error handling
































