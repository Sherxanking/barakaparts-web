-- ============================================
-- QUICK FIX: Users Table RLS + Boss User
-- ============================================
-- 
-- MUAMMO: boss@test.com login qilganda "Database permission error"
-- SABAB: users jadvalida RLS policies yo'q yoki trigger ishlamayapti
-- 
-- YECHIM: 
-- 1. Users jadvali uchun RLS policies yaratish
-- 2. Boss user'ni qo'lda yaratish
-- 3. Trigger'ni tuzatish
-- ============================================

-- ============================================
-- STEP 1: USERS TABLE RLS POLICIES
-- ============================================

-- RLS yoqilganligini tekshirish va yoqish
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'users'
    AND rowsecurity = true
  ) THEN
    ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE '✅ RLS enabled on public.users';
  ELSE
    RAISE NOTICE '✅ RLS already enabled on public.users';
  END IF;
END $$;

-- Eski policies'ni o'chirish
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users read self" ON public.users;
DROP POLICY IF EXISTS "Boss can read all users" ON public.users;
DROP POLICY IF EXISTS "Manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users insert self" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Users update self" ON public.users;
DROP POLICY IF EXISTS "Boss can update users" ON public.users;
DROP POLICY IF EXISTS "Boss update all users" ON public.users;

-- ============================================
-- STEP 2: YANGI RLS POLICIES YARATISH
-- ============================================

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
-- MUHIM: Bu trigger ishlashi uchun zarur!
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
-- STEP 3: BOSS USER'NI QO'LDA YARATISH
-- ============================================

-- Boss user'ni yaratish/yangilash
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

-- Manager user'ni ham tekshirish va yaratish
INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  id,
  'Manager',
  email,
  'manager',
  COALESCE(created_at, NOW())
FROM auth.users
WHERE LOWER(email) = 'manager@test.com'
ON CONFLICT (id) DO UPDATE
SET
  name = 'Manager',
  email = EXCLUDED.email,
  role = 'manager',
  updated_at = NOW();

-- ============================================
-- STEP 4: TRIGGER FUNCTION'NI YARATISH/YANGILASH
-- ============================================

-- Trigger function'ni SECURITY DEFINER bilan yaratish/yangilash
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
  -- Email ni olish
  user_email := COALESCE(NEW.email, '');
  
  -- Metadata'dan role olish
  metadata_role := NEW.raw_user_meta_data->>'role';
  
  -- FIX: Test accountlar uchun role'ni email'dan aniqlash (AVVAL TEKSHIRISH)
  IF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
    RAISE NOTICE '✅ Test account detected: manager@test.com -> role: manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
    RAISE NOTICE '✅ Test account detected: boss@test.com -> role: boss';
  ELSIF metadata_role IS NOT NULL AND metadata_role != '' THEN
    -- Metadata'da role bo'lsa, uni ishlatish
    user_role := metadata_role;
    RAISE NOTICE '✅ Role from metadata: %', metadata_role;
  ELSE
    -- Metadata'da role bo'lmasa, default 'worker'
    user_role := 'worker';
    RAISE NOTICE '⚠️ No role in metadata, using default: worker';
  END IF;
  
  -- Role validatsiyasi (faqat ruxsat etilgan rollar)
  IF user_role NOT IN ('worker', 'manager', 'boss') THEN
    -- Test account bo'lsa, to'g'ri role o'rnatish
    IF LOWER(user_email) = 'manager@test.com' THEN
      user_role := 'manager';
    ELSIF LOWER(user_email) = 'boss@test.com' THEN
      user_role := 'boss';
    ELSE
      user_role := 'worker';
    END IF;
    RAISE WARNING 'Invalid role detected, corrected to: %', user_role;
  END IF;
  
  -- Name ni metadata'dan olish
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  -- public.users jadvaliga INSERT qilish
  -- SECURITY DEFINER tufayli RLS o'tkazib yuboriladi
  INSERT INTO public.users (id, name, email, role, created_at)
  VALUES (
    NEW.id,
    user_name,
    user_email,
    user_role,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    name = COALESCE(EXCLUDED.name, users.name),
    email = COALESCE(EXCLUDED.email, users.email),
    -- FIX: Test accountlar uchun role'ni har doim yangilash
    role = CASE 
      WHEN LOWER(EXCLUDED.email) = 'manager@test.com' THEN 'manager'
      WHEN LOWER(EXCLUDED.email) = 'boss@test.com' THEN 'boss'
      ELSE COALESCE(EXCLUDED.role, users.role, 'worker')
    END,
    updated_at = NOW();
  
  RAISE NOTICE '✅ User profile created/updated: % (role: %)', user_email, user_role;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Xatolik bo'lsa, log qilish
    RAISE WARNING 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- ============================================
-- STEP 5: TRIGGER'NI YARATISH/YANGILASH
-- ============================================

-- Eski trigger'ni o'chirish
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Yangi trigger yaratish
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 6: TEKSHIRISH
-- ============================================

-- Boss user'ni tekshirish
DO $$
DECLARE
  boss_exists BOOLEAN;
  boss_role TEXT;
  boss_id UUID;
BEGIN
  -- auth.users'dan ID olish
  SELECT id INTO boss_id
  FROM auth.users
  WHERE LOWER(email) = 'boss@test.com'
  LIMIT 1;
  
  IF boss_id IS NULL THEN
    RAISE WARNING '⚠️ boss@test.com auth.users jadvalida topilmadi!';
    RAISE NOTICE '📝 Avval auth.users jadvalida user yaratishingiz kerak.';
  ELSE
    -- public.users'da tekshirish
    SELECT EXISTS(
      SELECT 1 FROM public.users 
      WHERE id = boss_id
    ) INTO boss_exists;
    
    IF boss_exists THEN
      SELECT role INTO boss_role
      FROM public.users
      WHERE id = boss_id;
      
      IF boss_role = 'boss' THEN
        RAISE NOTICE '✅ boss@test.com mavjud va role: boss';
      ELSE
        RAISE WARNING '⚠️ boss@test.com mavjud lekin role: % (boss bo''lishi kerak)', boss_role;
        -- Role'ni tuzatish
        UPDATE public.users
        SET role = 'boss'
        WHERE id = boss_id;
        RAISE NOTICE '✅ boss@test.com role tuzatildi: boss';
      END IF;
    ELSE
      RAISE WARNING '⚠️ boss@test.com public.users jadvalida topilmadi!';
      RAISE NOTICE '📝 User qo''lda yaratilmoqda...';
      -- Qo'lda yaratish
      INSERT INTO public.users (id, name, email, role, created_at)
      VALUES (boss_id, 'Boss', 'boss@test.com', 'boss', NOW())
      ON CONFLICT (id) DO UPDATE
      SET role = 'boss', updated_at = NOW();
      RAISE NOTICE '✅ boss@test.com qo''lda yaratildi/yangilandi';
    END IF;
  END IF;
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Users jadvali uchun RLS policies yaratildi
-- ✅ Boss user qo'lda yaratildi/yangilandi
-- ✅ Trigger function SECURITY DEFINER bilan yangilandi
-- ✅ Trigger yaratildi/yangilandi
-- ✅ Endi boss@test.com bilan login ishlashi kerak






























