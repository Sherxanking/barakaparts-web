-- ============================================
-- FIX LOGIN PERMISSION - Darhol Ishlaydigan Yechim
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
-- STEP 1: SECURITY DEFINER funksiyasi yaratish
-- (Bu funksiya RLS'ni chetlab o'tadi)
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
  INSERT INTO public.users (id, name, email, role, created_at)
  VALUES (user_id, user_name, user_email, user_role, NOW())
  ON CONFLICT (id) DO UPDATE
  SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    updated_at = NOW();
END;
$$;

-- ============================================
-- STEP 2: User'ni qo'lda qo'shish (SECURITY DEFINER orqali)
-- ============================================
SELECT public.create_user_profile(
  '48ac9358-b302-4b01-9706-0c1600497a1c'::UUID,
  'Boss',
  'boss@test.com',
  'boss'
);

-- ============================================
-- STEP 3: Barcha mavjud userlarni sinxronlashtirish
-- ============================================
DO $$
DECLARE
  auth_user RECORD;
BEGIN
  FOR auth_user IN 
    SELECT 
      id,
      email,
      raw_user_meta_data
    FROM auth.users
  LOOP
    PERFORM public.create_user_profile(
      auth_user.id,
      COALESCE(
        auth_user.raw_user_meta_data->>'name',
        auth_user.raw_user_meta_data->>'full_name',
        split_part(COALESCE(auth_user.email, ''), '@', 1),
        'User'
      ),
      COALESCE(auth_user.email, ''),
      CASE 
        WHEN LOWER(COALESCE(auth_user.email, '')) = 'manager@test.com' THEN 'manager'
        WHEN LOWER(COALESCE(auth_user.email, '')) = 'boss@test.com' THEN 'boss'
        ELSE COALESCE(auth_user.raw_user_meta_data->>'role', 'worker')
      END
    );
  END LOOP;
END $$;

-- ============================================
-- STEP 4: Barcha eski RLS policies'ni o'chirish
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
  RAISE NOTICE '✅ Barcha eski policies o''chirildi';
END $$;

-- ============================================
-- STEP 5: RLS'ni yoqish
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 6: Yangi RLS Policies yaratish (recursion yo'q)
-- ============================================

-- Policy 1: User o'z ma'lumotlarini o'qishi mumkin (MUHIM!)
CREATE POLICY "Users can read own profile"
ON public.users
FOR SELECT
USING (auth.uid() = id);

-- Policy 2: Boss va Manager barcha userlarni o'qishi mumkin
-- (auth.users'dan to'g'ridan-to'g'ri o'qiydi, recursion yo'q)
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
-- STEP 7: Trigger funksiyasini yangilash
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
  -- Email va metadata'dan role olish
  user_email := COALESCE(NEW.email, '');
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', '');
  
  -- Email asosida role belgilash (test accountlar uchun)
  IF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF user_role = '' OR user_role IS NULL THEN
    user_role := 'worker';
  END IF;
  
  -- Name olish
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  -- User profile yaratish
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
-- STEP 8: Trigger'ni qayta yaratish
-- ============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 9: Grant permissions
-- ============================================
-- Authenticated userlar uchun funksiyani chaqirishga ruxsat
GRANT EXECUTE ON FUNCTION public.create_user_profile TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
-- User'ni tekshirish
SELECT id, name, email, role, created_at
FROM public.users 
WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';

-- Barcha userlarni ko'rish
SELECT id, name, email, role FROM public.users ORDER BY created_at DESC;

-- Policies'ni tekshirish
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'users'
ORDER BY policyname;















