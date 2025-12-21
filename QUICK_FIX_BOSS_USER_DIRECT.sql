-- ============================================
-- DIRECT FIX: Boss User - Step by Step
-- ============================================
-- 
-- Bu SQL'ni Supabase Dashboard → SQL Editor'da ishga tushiring
-- Har bir qismni alohida ishga tushirishingiz mumkin
-- ============================================

-- ============================================
-- STEP 1: AUTH.USERS'DAN BOSS USER ID'NI TOPISH
-- ============================================
-- Avval boss@test.com user'ning ID'sini topamiz

SELECT id, email, created_at 
FROM auth.users 
WHERE LOWER(email) = 'boss@test.com';

-- Agar natija bo'sh bo'lsa, boss@test.com auth.users'da yo'q
-- Bu holda avval Supabase Dashboard → Authentication → Users orqali user yaratishingiz kerak

-- ============================================
-- STEP 2: PUBLIC.USERS'DA BOSS USER'NI YARATISH
-- ============================================
-- Yuqoridagi so'rovdan olingan ID'ni ishlatib, user'ni yaratamiz
-- ID'ni o'z ID'ingizga o'zgartiring!

-- Variant A: Agar ID ma'lum bo'lsa
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

-- Variant B: Agar ID noma'lum bo'lsa (avtomatik topadi)
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

-- ============================================
-- STEP 3: RLS POLICIES'NI YARATISH
-- ============================================

-- RLS yoqish
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Eski policies'ni o'chirish
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Boss can update all users" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Users read self" ON public.users;
DROP POLICY IF EXISTS "Users insert self" ON public.users;
DROP POLICY IF EXISTS "Users update self" ON public.users;
DROP POLICY IF EXISTS "Boss read all users" ON public.users;
DROP POLICY IF EXISTS "Manager read all users" ON public.users;
DROP POLICY IF EXISTS "Boss update all users" ON public.users;

-- Policy 1: User o'z ma'lumotlarini o'qishi mumkin
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
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role IN ('boss', 'manager')
  )
);

-- Policy 3: User o'z ma'lumotlarini INSERT qilishi mumkin (trigger uchun)
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

-- ============================================
-- STEP 4: TRIGGER FUNCTION'NI YARATISH
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  user_role TEXT;
  user_name TEXT;
  user_email TEXT;
  metadata_role TEXT;
BEGIN
  user_email := COALESCE(NEW.email, '');
  metadata_role := NEW.raw_user_meta_data->>'role';
  
  -- Test accountlar
  IF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF metadata_role IS NOT NULL AND metadata_role != '' THEN
    user_role := metadata_role;
  ELSE
    user_role := 'worker';
  END IF;
  
  -- Validatsiya
  IF user_role NOT IN ('worker', 'manager', 'boss') THEN
    IF LOWER(user_email) = 'manager@test.com' THEN
      user_role := 'manager';
    ELSIF LOWER(user_email) = 'boss@test.com' THEN
      user_role := 'boss';
    ELSE
      user_role := 'worker';
    END IF;
  END IF;
  
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  -- INSERT (SECURITY DEFINER tufayli RLS o'tkazib yuboriladi)
  INSERT INTO public.users (id, name, email, role, created_at)
  VALUES (NEW.id, user_name, user_email, user_role, NOW())
  ON CONFLICT (id) DO UPDATE
  SET
    name = COALESCE(EXCLUDED.name, users.name),
    email = COALESCE(EXCLUDED.email, users.email),
    role = CASE 
      WHEN LOWER(EXCLUDED.email) = 'manager@test.com' THEN 'manager'
      WHEN LOWER(EXCLUDED.email) = 'boss@test.com' THEN 'boss'
      ELSE COALESCE(EXCLUDED.role, users.role, 'worker')
    END,
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- ============================================
-- STEP 5: TRIGGER'NI YARATISH
-- ============================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 6: TEKSHIRISH
-- ============================================

-- Boss user'ni tekshirish
SELECT id, email, role, name
FROM public.users 
WHERE LOWER(email) = 'boss@test.com';

-- Agar natija bo'sh bo'lsa yoki role 'boss' emas bo'lsa:
-- Yuqoridagi STEP 2'ni qayta ishga tushiring














