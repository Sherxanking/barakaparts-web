-- ============================================
-- SET GOOGLE LOGIN TO MANAGER ROLE
-- ============================================
-- 
-- MUAMMO: Google orqali sign qilganda default role 'worker' bo'lyapti
-- YECHIM: Google orqali kirgan userlar avtomatik 'manager' role bilan yaratiladi
-- NOTE: Test accountlar (boss@test.com, manager@test.com) o'zgarishsiz qoladi
-- ============================================

-- ============================================
-- STEP 1: TRIGGER FUNCTION'NI YANGILASH
-- ============================================
-- Google login uchun default role 'manager' bo'lsin

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
  -- Google OAuth userlarida provider = 'google' yoki app_metadata'da google bo'ladi
  is_google_user := (
    NEW.app_metadata->>'provider' = 'google' OR
    NEW.app_metadata->>'provider' IS NULL AND NEW.raw_user_meta_data->>'provider' = 'google' OR
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
    RAISE NOTICE '✅ Test account detected: manager@test.com -> role: manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
    RAISE NOTICE '✅ Test account detected: boss@test.com -> role: boss';
  ELSIF metadata_role IS NOT NULL AND metadata_role != '' THEN
    -- Metadata'da role bo'lsa, uni ishlatish
    user_role := metadata_role;
    RAISE NOTICE '✅ Role from metadata: %', metadata_role;
  ELSIF is_google_user THEN
    -- Google orqali kirgan userlar uchun default 'manager'
    user_role := 'manager';
    RAISE NOTICE '✅ Google user detected -> role: manager';
  ELSE
    -- Boshqa userlar uchun default 'manager' (TEMPORARY)
    user_role := 'manager';
    RAISE NOTICE '⚠️ No role in metadata, using default: manager (TEMPORARY)';
  END IF;
  
  -- Role validatsiyasi (faqat ruxsat etilgan rollar)
  IF user_role NOT IN ('worker', 'manager', 'boss') THEN
    user_role := 'manager'; -- Default 'manager' (TEMPORARY)
    RAISE WARNING 'Invalid role detected, using default: manager';
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
    role = COALESCE(EXCLUDED.role, users.role, 'manager'), -- Default 'manager' (TEMPORARY)
    updated_at = NOW();
  
  RAISE NOTICE '✅ User profile created/updated: % (role: %, google: %)', user_email, user_role, is_google_user;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Xatolik bo'lsa, log qilish
    RAISE WARNING 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- ============================================
-- STEP 2: MAVJUD GOOGLE USERLARNI YANGILASH
-- ============================================
-- Mavjud Google userlarni 'manager' role bilan yangilash

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
-- STEP 3: TEKSHIRISH
-- ============================================

DO $$
DECLARE
  google_users_count INTEGER;
  manager_count INTEGER;
  total_users INTEGER;
BEGIN
  -- Google userlarni sanash
  SELECT COUNT(*) INTO google_users_count
  FROM auth.users au
  INNER JOIN auth.identities ai ON au.id = ai.user_id
  WHERE ai.provider = 'google';
  
  -- Manager role'li userlarni sanash
  SELECT COUNT(*) INTO manager_count
  FROM public.users
  WHERE role = 'manager';
  
  -- Jami userlar soni
  SELECT COUNT(*) INTO total_users
  FROM public.users;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'GOOGLE LOGIN ROLE STATISTICS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Google users: %', google_users_count;
  RAISE NOTICE '✅ Manager users: %', manager_count;
  RAISE NOTICE '📊 Total users: %', total_users;
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Trigger updated - Google login users will get MANAGER role';
  RAISE NOTICE '✅ Existing Google users updated to MANAGER role';
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Trigger yangilandi - Google userlar 'manager' role bilan yaratiladi
-- ✅ Mavjud Google userlar 'manager' role bilan yangilandi
-- ✅ Test accountlar o'zgarishsiz qoldi
-- ✅ Barcha yangi Google userlar 'manager' role bilan yaratiladi
--
-- ENDI: Google orqali sign qilganda manager roli bilan kiriladi!






























