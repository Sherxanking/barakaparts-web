# Boss User Xatolikni Tuzatish - To'liq Qo'llanma

## 🔴 MUAMMO
`boss@test.com` bilan login qilganda:
```
Database permission error. Trigger may not be working.
Please run migration 015_fix_role_for_dashboard_users.sql
Or manually add user:
INSERT INTO users (id, name, email, role)
VALUES ('48ac9358-b302-4b01-9706-0c1600497a1c', 'boss', 'boss@test.com', 'boss')
ON CONFLICT (id) DO NOTHING;
```

## ✅ YECHIM: 3 QADAM

### QADAM 1: Auth Users'da Boss User'ni Tekshirish

Supabase Dashboard → SQL Editor'da:

```sql
-- Boss user auth.users'da bormi?
SELECT id, email, created_at 
FROM auth.users 
WHERE LOWER(email) = 'boss@test.com';
```

**Agar natija bo'sh bo'lsa:**
- Supabase Dashboard → Authentication → Users ga kiring
- "Add user" tugmasini bosing
- Email: `boss@test.com`
- Password: `Boss123!`
- Auto Confirm: ON
- "Create user" tugmasini bosing

### QADAM 2: Public Users'da Boss User'ni Yaratish

SQL Editor'da (yuqoridagi so'rovdan olingan ID'ni ishlatib):

```sql
-- ID'ni o'z ID'ingizga o'zgartiring!
INSERT INTO public.users (id, name, email, role, created_at)
VALUES (
  '48ac9358-b302-4b01-9706-0c1600497a1c',  -- O'z ID'ingizni qo'ying!
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

**Yoki avtomatik (ID noma'lum bo'lsa):**

```sql
INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  id,
  'Boss',
  email,
  'boss',
  COALESCE(created_at, NOW())
FROM auth.users
WHERE LOWER(email) = 'boss@test.com'
ON CONFLICT (id) DO UPDATE
SET
  name = 'Boss',
  email = EXCLUDED.email,
  role = 'boss',
  updated_at = NOW();
```

### QADAM 3: RLS Policies va Trigger'ni Tuzatish

SQL Editor'da `QUICK_FIX_BOSS_USER_DIRECT.sql` faylini ochib, STEP 3, 4, 5'ni ishga tushiring.

Yoki quyidagi SQL'ni ishga tushiring:

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
WHERE LOWER(email) = 'boss@test.com';
```

**Natija:**
- `email`: `boss@test.com`
- `role`: `boss`
- `name`: `Boss`

## 📱 APP'NI TEST QILISH

1. App'ni qayta ishga tushiring
2. `boss@test.com` / `Boss123!` bilan login qiling
3. Endi ishlashi kerak!

## ⚠️ AGAR HALI HAM XATOLIK BO'LSA

1. **User ID'ni to'g'ri tekshiring:**
   ```sql
   SELECT id FROM auth.users WHERE LOWER(email) = 'boss@test.com';
   ```

2. **Public users'da user borligini tekshiring:**
   ```sql
   SELECT * FROM public.users WHERE LOWER(email) = 'boss@test.com';
   ```

3. **Agar user yo'q bo'lsa, qo'lda yarating:**
   ```sql
   -- ID'ni yuqoridagi so'rovdan olingan ID'ga o'zgartiring
   INSERT INTO public.users (id, name, email, role)
   VALUES ('YOUR_USER_ID_HERE', 'Boss', 'boss@test.com', 'boss')
   ON CONFLICT (id) DO UPDATE SET role = 'boss';
   ```

4. **RLS policies'ni tekshiring:**
   ```sql
   SELECT * FROM pg_policies 
   WHERE schemaname = 'public' 
   AND tablename = 'users';
   ```

5. **Trigger'ni tekshiring:**
   ```sql
   SELECT * FROM pg_trigger 
   WHERE tgname = 'on_auth_user_created';
   ```






























