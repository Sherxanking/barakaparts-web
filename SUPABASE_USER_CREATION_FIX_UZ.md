# ✅ Supabase'da User Yaratish Muammosini Tuzatish

**Muammo:** Supabase'da yangi user yarata olmayapsiz ("create yuq")

**Sabab:** Trigger yoki RLS siyosatlari to'g'ri sozlangan emas.

---

## 🔧 YECHIM

### STEP 1: Supabase Dashboard'ga Kirish

1. Supabase Dashboard'ga kiring: https://supabase.com/dashboard
2. Loyihangizni tanlang
3. **SQL Editor** ga o'ting (chap menudan)

---

### STEP 2: Migratsiyani Qo'llash

1. **SQL Editor** da yangi query yarating
2. `supabase/migrations/013_complete_user_creation_fix.sql` faylini oching
3. Barcha SQL kodini nusxalab, SQL Editor'ga yopishtiring
4. **RUN** tugmasini bosing

**Kutilgan natija:**
```
✅ Users jadvali mavjud/yangilandi
✅ RLS yoqildi
✅ RLS siyosatlari yaratildi
✅ Trigger function yaratildi
✅ Trigger qo'shildi
✅ Barcha tekshiruvlar o'tdi!
```

---

### STEP 3: Tekshirish

#### 3.1. Trigger Mavjudligini Tekshirish

SQL Editor'da quyidagi kodni bajarish:

```sql
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';
```

**Kutilgan natija:** 1 qator (trigger mavjud)

---

#### 3.2. Function Mavjudligini Tekshirish

```sql
SELECT 
  proname as function_name,
  prosecdef as is_security_definer
FROM pg_proc 
WHERE proname = 'handle_new_user'
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
```

**Kutilgan natija:** 
- `function_name = handle_new_user`
- `is_security_definer = true` (MUHIM!)

---

#### 3.3. RLS Siyosatlarini Tekshirish

```sql
SELECT 
  policyname,
  cmd as command
FROM pg_policies
WHERE tablename = 'users';
```

**Kutilgan natija:** Kamida 5 ta siyosat:
- Users can read own data
- Boss and manager can read all users
- Users can insert own data (MUHIM!)
- Users can update own data
- Boss can update users

---

## 🧪 Test Qilish

### Test 1: Flutter App'da User Yaratish

1. Flutter app'ni ishga tushiring
2. Boss yoki Manager sifatida login qiling
3. Admin Panel'ga o'ting
4. "Create User" tugmasini bosing
5. Yangi user ma'lumotlarini kiriting:
   - Email: `test@example.com`
   - Password: `Test123!`
   - Name: `Test User`
   - Role: `worker`
6. "Create" tugmasini bosing

**Kutilgan natija:**
- ✅ "User created successfully" xabari ko'rsatiladi
- ✅ Yangi user ro'yxatda ko'rinadi

---

### Test 2: Supabase Dashboard'da Tekshirish

1. Supabase Dashboard → **Authentication** → **Users**
2. Yangi yaratilgan user ko'rinishi kerak
3. Supabase Dashboard → **Table Editor** → **users**
4. `public.users` jadvalida ham user ko'rinishi kerak

---

## ❌ Agar Muammo Davom Etsa

### Muammo 1: "Permission denied" xatosi

**Sabab:** Trigger SECURITY DEFINER bilan yaratilmagan

**Yechim:**
```sql
-- Function'ni qayta yaratish
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER  -- MUHIM!
SET search_path = public
LANGUAGE plpgsql
AS $$
-- ... function body
$$;
```

---

### Muammo 2: "Trigger does not exist" xatosi

**Sabab:** Trigger yaratilmagan

**Yechim:**
```sql
-- Trigger'ni yaratish
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

---

### Muammo 3: "RLS policy violation" xatosi

**Sabab:** INSERT siyosati mavjud emas

**Yechim:**
```sql
-- INSERT siyosatini yaratish
CREATE POLICY "Users can insert own data" ON public.users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);
```

---

## 📋 Qo'shimcha Tekshiruvlar

### Users Jadvali Strukturasi

```sql
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'users'
AND table_schema = 'public'
ORDER BY ordinal_position;
```

**Kutilgan columnlar:**
- `id` (UUID, PRIMARY KEY)
- `name` (TEXT, NOT NULL)
- `email` (TEXT, UNIQUE, NOT NULL)
- `role` (TEXT, NOT NULL, DEFAULT 'worker')
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

---

## ✅ Muvaffaqiyatli Tuzatilgandan Keyin

1. ✅ Yangi user yaratish ishlaydi
2. ✅ Trigger avtomatik `public.users` ga yozadi
3. ✅ RLS xavfsizlik saqlanadi
4. ✅ Barcha rollar to'g'ri ishlaydi

---

## 📝 Xulosa

**Asosiy muammo:** Trigger yoki RLS siyosatlari to'g'ri sozlangan emas.

**Yechim:**
1. ✅ `013_complete_user_creation_fix.sql` migratsiyasini qo'llash
2. ✅ Trigger'ni SECURITY DEFINER bilan yaratish
3. ✅ RLS siyosatlarini to'g'ri sozlash

**Fayl:** `supabase/migrations/013_complete_user_creation_fix.sql`

---

## 🆘 Yordam

Agar muammo davom etsa:

1. Supabase Dashboard → **Logs** → **Postgres Logs** ni tekshiring
2. Xatolik xabarlarini ko'ring
3. Flutter app'da debug console'ni tekshiring
4. `USER_CREATION_ERROR_FIX.md` faylini o'qing






























