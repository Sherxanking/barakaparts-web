-- ============================================
-- FIX NOW - SODDA VA ANIQ YECHIM
-- ============================================
-- 
-- QADAM 1: Bu SQL'ni Supabase SQL Editor'da RUN qiling
-- QADAM 2: Appni qayta ishga tushiring
-- QADAM 3: Login qiling
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

-- STEP 5: RLS'NI QAYTA YOQISH
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- STEP 6: YANGI POLICIES YARATISH
CREATE POLICY "Users can read own profile"
ON public.users
FOR SELECT
USING (auth.uid() = id);

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

CREATE POLICY "Users can insert own profile"
ON public.users
FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

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

-- STEP 7: SECURITY DEFINER FUNKSIYASI
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

-- STEP 8: TRIGGER
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

GRANT EXECUTE ON FUNCTION public.create_user_profile TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user TO authenticated;

-- VERIFICATION
SELECT id, name, email, role FROM public.users WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';








