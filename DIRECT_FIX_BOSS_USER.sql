-- ============================================
-- DIRECT FIX: Boss User - Qo'lda Yaratish
-- ============================================
-- 
-- Bu SQL'ni Supabase Dashboard → SQL Editor'da ishga tushiring
-- Xatolik xabaridagi ID'ni ishlatib, user'ni to'g'ridan-to'g'ri yaratamiz
-- ============================================

-- ============================================
-- STEP 1: BOSS USER'NI QO'LDA YARATISH
-- ============================================
-- Xatolik xabaridagi ID'ni ishlatamiz

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

-- ============================================
-- STEP 2: TEKSHIRISH
-- ============================================

SELECT id, email, role, name
FROM public.users 
WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';

-- Natija: role = 'boss' bo'lishi kerak

-- ============================================
-- STEP 3: RLS POLICIES (AGAR KERAK BO'LSA)
-- ============================================

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

-- ============================================
-- STEP 4: TRIGGER FUNCTION (AGAR KERAK BO'LSA)
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
  
  IF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF metadata_role IS NOT NULL AND metadata_role != '' THEN
    user_role := metadata_role;
  ELSE
    user_role := 'worker';
  END IF;
  
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

-- Trigger yaratish
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();
































