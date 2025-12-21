-- ============================================
-- SIMPLE FIX - SODDA YECHIM
-- ============================================
-- 
-- Faqat 3 ta user: o'zingiz, manager, boss
-- RLS'ni minimal darajada sozlaymiz
-- 
-- ============================================

-- STEP 1: RLS'NI O'CHIRISH
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- STEP 2: BARCHA POLICIES'NI O'CHIRISH
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
END $$;

-- STEP 3: USER'NI QO'SHISH
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

-- STEP 4: AUTH.USERS'DA ROLE'NI SOZLASH
UPDATE auth.users
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role": "boss"}'::jsonb
WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c'::UUID;

-- STEP 5: SODDA RLS POLICIES (Faqat authenticated userlar uchun)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Faqat authenticated userlar o'qishi mumkin
CREATE POLICY "Authenticated users can read all"
ON public.users
FOR SELECT
TO authenticated
USING (true);

-- Faqat authenticated userlar qo'shishi mumkin
CREATE POLICY "Authenticated users can insert"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Faqat authenticated userlar yangilashi mumkin
CREATE POLICY "Authenticated users can update"
ON public.users
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- STEP 6: TRIGGER (Yangi userlar avtomatik yaratilishi uchun)
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
  
  INSERT INTO public.users (id, name, email, role, created_at, updated_at)
  VALUES (NEW.id, user_name, user_email, user_role, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE
  SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    updated_at = NOW();
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- VERIFICATION
SELECT id, name, email, role FROM public.users WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';














