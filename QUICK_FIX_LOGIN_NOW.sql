-- ============================================
-- QUICK FIX: Login Muammosini Hal Qilish
-- ============================================
-- 
-- QADAM 1: Avval bu SQL'ni ishga tushiring (user'ni qo'shish)
-- QADAM 2: Keyin COMPLETE_FINAL_MIGRATION.sql ni ishga tushiring
-- 
-- ============================================

-- ============================================
-- STEP 1: User'ni qo'lda qo'shish (login qilish uchun)
-- ============================================
-- Sizning user ID'ingiz: 48ac9358-b302-4b01-9706-0c1600497a1c

INSERT INTO public.users (id, name, email, role, created_at)
VALUES (
  '48ac9358-b302-4b01-9706-0c1600497a1c',
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

-- ============================================
-- STEP 2: Boshqa mavjud userlarni ham qo'shish
-- ============================================
-- Barcha auth.users'dagi userlarni public.users'ga qo'shish
INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  au.id,
  COALESCE(
    au.raw_user_meta_data->>'name',
    au.raw_user_meta_data->>'full_name',
    split_part(COALESCE(au.email, ''), '@', 1),
    'User'
  ) as name,
  COALESCE(au.email, '') as email,
  CASE 
    WHEN LOWER(COALESCE(au.email, '')) = 'manager@test.com' THEN 'manager'
    WHEN LOWER(COALESCE(au.email, '')) = 'boss@test.com' THEN 'boss'
    ELSE COALESCE(au.raw_user_meta_data->>'role', 'worker')
  END as role,
  COALESCE(au.created_at, NOW()) as created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO UPDATE
SET
  name = COALESCE(EXCLUDED.name, public.users.name),
  email = COALESCE(EXCLUDED.email, public.users.email),
  role = CASE 
    WHEN LOWER(EXCLUDED.email) = 'manager@test.com' THEN 'manager'
    WHEN LOWER(EXCLUDED.email) = 'boss@test.com' THEN 'boss'
    ELSE COALESCE(EXCLUDED.role, public.users.role, 'worker')
  END,
  updated_at = NOW();

-- ============================================
-- STEP 3: RLS Policies'ni to'liq qo'shish
-- ============================================
-- Avval barcha eski policies'ni o'chirish
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.users';
  END LOOP;
END $$;

-- RLS'ni yoqish
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policy 1: User o'z ma'lumotlarini o'qishi mumkin (MUHIM!)
CREATE POLICY "Users can read own profile"
ON public.users
FOR SELECT
USING (auth.uid() = id);

-- Policy 2: Boss va Manager barcha userlarni o'qishi mumkin
CREATE POLICY "Boss and manager can read all users"
ON public.users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'boss' OR
      auth.users.raw_user_meta_data->>'role' = 'manager'
    )
  )
);

-- Policy 3: User o'z ma'lumotlarini INSERT qilishi mumkin (auto-create uchun)
CREATE POLICY "Users can insert own profile"
ON public.users
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy 4: User o'z ma'lumotlarini UPDATE qilishi mumkin
CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 5: Boss barcha userlarni UPDATE qilishi mumkin
CREATE POLICY "Boss can update all users"
ON public.users
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'role' = 'boss'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'role' = 'boss'
  )
);

-- ============================================
-- VERIFICATION
-- ============================================
-- User'ni tekshirish
SELECT id, name, email, role 
FROM public.users 
WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';

-- Barcha userlarni ko'rish
SELECT id, name, email, role FROM public.users;

