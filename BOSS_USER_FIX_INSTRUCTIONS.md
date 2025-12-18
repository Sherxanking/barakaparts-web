# Boss User Xatolikni Tuzatish - Qadam-baqadam

## 🔴 MUAMMO
`boss@test.com` bilan login qilganda:
```
Database permission error. Trigger may not be working.
```

## ✅ YECHIM: 2 QADAM

### QADAM 1: User'ni Qo'lda Yaratish (ENG MUHIM!)

Supabase Dashboard → SQL Editor'da quyidagi SQL'ni ishga tushiring:

```sql
-- Boss user'ni to'g'ridan-to'g'ri yaratish
INSERT INTO public.users (id, name, email, role, created_at)
VALUES (
  '48ac9358-b302-4b01-9706-0c1600497a1c',  -- Xatolik xabaridagi ID
  'Boss',
  'boss@test.com',
  'boss',
  NOW()
)
ON CONFLICT (id) DO UPDATE
SET
  name = 'Boss',
  email = 'boss@test.com',
  role = 'boss',
  updated_at = NOW();
```

**Natija:** `Success. 1 row affected` yoki `Success. 0 rows affected` (agar allaqachon mavjud bo'lsa)

### QADAM 2: RLS Policies'ni Yaratish

Agar hali ham xatolik bo'lsa, quyidagi SQL'ni ishga tushiring:

```sql
-- RLS yoqish
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Eski policies'ni o'chirish
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Boss can update all users" ON public.users;

-- Yangi policies yaratish
CREATE POLICY "Users can read own profile"
ON public.users FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Boss and manager can read all users"
ON public.users FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role IN ('boss', 'manager')
  )
);

CREATE POLICY "Users can insert own profile"
ON public.users FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Boss can update all users"
ON public.users FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role = 'boss'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role = 'boss'
  )
);
```

## 🧪 TEKSHIRISH

SQL Editor'da:

```sql
-- Boss user'ni tekshirish
SELECT id, email, role, name
FROM public.users 
WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';
```

**Kutilgan natija:**
- `email`: `boss@test.com`
- `role`: `boss`
- `name`: `Boss`

## 📱 APP'NI TEST QILISH

1. App'ni to'liq yopib qayta ishga tushiring
2. `boss@test.com` / `Boss123!` bilan login qiling
3. Endi ishlashi kerak!

## ⚠️ AGAR HALI HAM XATOLIK BO'LSA

1. **User ID'ni tekshiring:**
   ```sql
   SELECT id, email FROM auth.users WHERE LOWER(email) = 'boss@test.com';
   ```
   
   Agar natija bo'sh bo'lsa, boss@test.com auth.users'da yo'q!
   Bu holda:
   - Supabase Dashboard → Authentication → Users
   - "Add user" tugmasini bosing
   - Email: `boss@test.com`
   - Password: `Boss123!`
   - Auto Confirm: ON
   - "Create user" tugmasini bosing

2. **Public users'da user borligini tekshiring:**
   ```sql
   SELECT * FROM public.users WHERE LOWER(email) = 'boss@test.com';
   ```
   
   Agar natija bo'sh bo'lsa, QADAM 1'ni qayta ishga tushiring.

3. **RLS policies'ni tekshiring:**
   ```sql
   SELECT policyname, cmd, qual 
   FROM pg_policies 
   WHERE schemaname = 'public' 
   AND tablename = 'users';
   ```
   
   Kamida 5 ta policy bo'lishi kerak.







