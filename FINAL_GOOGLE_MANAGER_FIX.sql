-- ============================================
-- FINAL GOOGLE MANAGER FIX - To'liq yechim
-- ============================================
-- 
-- MUAMMO: Google login bilan kirgan userlar worker roli bilan chiqyapti
-- SABAB: Eski migration'lar DEFAULT 'worker' o'rnatgan
-- YECHIM: Barcha joylarni 'manager' ga o'zgartirish
-- ============================================

-- ============================================
-- STEP 1: USERS TABLE DEFAULT VALUE'NI YANGILASH
-- ============================================

-- Role column default value'ni 'manager' ga o'zgartirish
ALTER TABLE public.users 
ALTER COLUMN role SET DEFAULT 'manager';

-- ============================================
-- STEP 2: MAVJUD GOOGLE USERLARNI MANAGER QILISH
-- ============================================

UPDATE public.users
SET role = 'manager'
WHERE id IN (
  SELECT au.id
  FROM auth.users au
  INNER JOIN auth.identities ai ON au.id = ai.user_id
  WHERE ai.provider = 'google'
  AND au.email NOT IN ('boss@test.com', 'manager@test.com')
)
AND role != 'manager'
AND role != 'boss';

-- ============================================
-- STEP 3: TRIGGER FUNCTION'NI TO'LIQ YANGILASH
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
  is_google_user BOOLEAN;
BEGIN
  -- Email ni olish
  user_email := COALESCE(NEW.email, '');
  
  -- Google user ekanligini aniqlash
  is_google_user := (
    NEW.app_metadata->>'provider' = 'google' OR
    (NEW.app_metadata->>'provider' IS NULL AND NEW.raw_user_meta_data->>'provider' = 'google') OR
    EXISTS (
      SELECT 1 FROM auth.identities
      WHERE user_id = NEW.id
      AND provider = 'google'
    )
  );
  
  -- Metadata'dan role olish
  metadata_role := NEW.raw_user_meta_data->>'role';
  
  -- FIX: Test accountlar uchun role'ni email'dan aniqlash
  IF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF metadata_role IS NOT NULL AND metadata_role != '' THEN
    -- Metadata'da role bo'lsa, uni ishlatish
    user_role := metadata_role;
  ELSIF is_google_user THEN
    -- Google orqali kirgan userlar uchun default 'manager'
    user_role := 'manager';
  ELSE
    -- Boshqa userlar uchun default 'manager'
    user_role := 'manager';
  END IF;
  
  -- Role validatsiyasi
  IF user_role NOT IN ('worker', 'manager', 'boss') THEN
    user_role := 'manager';
  END IF;
  
  -- Name ni metadata'dan olish
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  -- public.users jadvaliga INSERT qilish
  -- FIX: ON CONFLICT DO UPDATE da Google userlar har doim 'manager' bo'ladi
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
    -- FIX: Agar Google user bo'lsa, role har doim 'manager' bo'ladi
    role = CASE 
      WHEN is_google_user THEN 'manager'  -- Google userlar har doim manager
      WHEN EXCLUDED.role IS NOT NULL THEN EXCLUDED.role
      ELSE COALESCE(users.role, 'manager')
    END,
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- ============================================
-- STEP 4: BARCHA MAVJUD USERLARNI TEKSHIRISH
-- ============================================

-- Barcha userlarni role bo'yicha tekshirish
SELECT 
  role,
  COUNT(*) as count
FROM public.users
GROUP BY role
ORDER BY role;

-- Google userlarni tekshirish
SELECT 
  au.id,
  au.email,
  pu.role,
  ai.provider,
  CASE 
    WHEN pu.role = 'manager' THEN '✅ Manager'
    WHEN pu.role = 'worker' THEN '❌ Worker (needs update)'
    WHEN pu.role = 'boss' THEN '✅ Boss'
    ELSE '⚠️ Unknown'
  END as status
FROM auth.users au
INNER JOIN auth.identities ai ON au.id = ai.user_id
LEFT JOIN public.users pu ON au.id = pu.id
WHERE ai.provider = 'google'
ORDER BY pu.role, au.email;

-- ============================================
-- STEP 5: TEKSHIRISH VA STATISTIKA
-- ============================================

DO $$
DECLARE
  google_users_count INTEGER;
  manager_count INTEGER;
  worker_count INTEGER;
  boss_count INTEGER;
BEGIN
  -- Google userlarni sanash
  SELECT COUNT(*) INTO google_users_count
  FROM auth.users au
  INNER JOIN auth.identities ai ON au.id = ai.user_id
  WHERE ai.provider = 'google';
  
  -- Manager roli bilan userlarni sanash
  SELECT COUNT(*) INTO manager_count
  FROM public.users
  WHERE role = 'manager';
  
  -- Worker roli bilan userlarni sanash
  SELECT COUNT(*) INTO worker_count
  FROM public.users
  WHERE role = 'worker';
  
  -- Boss roli bilan userlarni sanash
  SELECT COUNT(*) INTO boss_count
  FROM public.users
  WHERE role = 'boss';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FINAL GOOGLE MANAGER FIX RESULTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Google users: %', google_users_count;
  RAISE NOTICE 'Manager users: %', manager_count;
  RAISE NOTICE 'Worker users: %', worker_count;
  RAISE NOTICE 'Boss users: %', boss_count;
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Default role changed to MANAGER';
  RAISE NOTICE '✅ Google users updated to MANAGER role';
  RAISE NOTICE '✅ Trigger function updated';
  RAISE NOTICE '✅ All new Google logins will get MANAGER role';
  RAISE NOTICE '========================================';
END $$;

-- ============================================
-- ✅ FIX COMPLETE
-- ============================================
-- Endi:
-- 1. Users table default role = 'manager'
-- 2. Mavjud Google userlar = 'manager'
-- 3. Trigger function Google userlar uchun 'manager' o'rnatadi
-- 4. Keyingi Google login'lar avtomatik 'manager' bo'ladi
-- ============================================















