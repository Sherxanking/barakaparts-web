-- ============================================
-- FIX PERMISSION - SODDA VA KUCHLI YECHIM
-- ============================================
-- 
-- Bu SQL barcha permission muammolarini hal qiladi
-- 
-- QADAM 1: Supabase Dashboard → SQL Editor
-- QADAM 2: Bu SQL'ni nusxalab, RUN qiling
-- QADAM 3: Appni qayta ishga tushiring va login qiling
-- 
-- ============================================

-- ============================================
-- STEP 1: RLS'NI TO'LIQ O'CHIRISH
-- ============================================
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 2: BARCHA POLICIES'NI O'CHIRISH
-- ============================================
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'users'
  ) LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.users';
  END LOOP;
  RAISE NOTICE '✅ Barcha policies o''chirildi';
END $$;

-- ============================================
-- STEP 3: USERS TABLE STRUCTURE'NI TEKSHIRISH
-- ============================================
DO $$
BEGIN
  -- updated_at column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.users ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    RAISE NOTICE '✅ updated_at column qo''shildi';
  END IF;
END $$;

-- ============================================
-- STEP 4: USER'NI QO'SHISH (RLS O'CHIRILGAN HOLDA)
-- ============================================
-- Boss user'ni qo'lda qo'shish
INSERT INTO public.users (id, name, email, role, created_at, updated_at)
VALUES (
  '48ac9358-b302-4b01-9706-0c1600497a1c'::UUID,
  'Boss',
  'boss@test.com',
  'boss',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE
SET
  name = 'Boss',
  email = 'boss@test.com',
  role = 'boss',
  updated_at = NOW();

-- Barcha auth.users'dagi userlarni sinxronlashtirish
INSERT INTO public.users (id, name, email, role, created_at, updated_at)
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
  COALESCE(au.created_at, NOW()) as created_at,
  NOW() as updated_at
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
-- STEP 5: SECURITY DEFINER FUNKSIYASI YARATISH
-- ============================================
CREATE OR REPLACE FUNCTION public.create_user_profile(
  user_id UUID,
  user_name TEXT,
  user_email TEXT,
  user_role TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, name, email, role, created_at, updated_at)
  VALUES (user_id, user_name, user_email, user_role, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE
  SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    updated_at = NOW();
END;
$$;

-- ============================================
-- STEP 6: RLS'NI QAYTA YOQISH
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 7: YANGI RLS POLICIES YARATISH
-- ============================================

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
      COALESCE(auth.users.raw_user_meta_data->>'role', '') = 'boss' OR
      COALESCE(auth.users.raw_user_meta_data->>'role', '') = 'manager'
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
    AND COALESCE(auth.users.raw_user_meta_data->>'role', '') = 'boss'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND COALESCE(auth.users.raw_user_meta_data->>'role', '') = 'boss'
  )
);

-- ============================================
-- STEP 8: TRIGGER FUNKSIYASINI YANGILASH
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role TEXT;
  user_name TEXT;
  user_email TEXT;
BEGIN
  user_email := COALESCE(NEW.email, '');
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', '');
  
  IF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF user_role = '' OR user_role IS NULL THEN
    user_role := 'worker';
  END IF;
  
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  PERFORM public.create_user_profile(
    NEW.id,
    user_name,
    user_email,
    user_role
  );
  
  RETURN NEW;
END;
$$;

-- ============================================
-- STEP 9: TRIGGER'NI QAYTA YARATISH
-- ============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 10: GRANT PERMISSIONS
-- ============================================
GRANT EXECUTE ON FUNCTION public.create_user_profile TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
-- User'ni tekshirish
SELECT id, name, email, role, created_at, updated_at
FROM public.users 
WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';

-- Barcha userlarni ko'rish
SELECT id, name, email, role FROM public.users ORDER BY created_at DESC;

-- Policies'ni tekshirish
SELECT policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'users'
ORDER BY policyname;

-- RLS holatini tekshirish
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'users';






























