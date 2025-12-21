-- ============================================
-- SET DEFAULT ROLE TO MANAGER (TEMPORARY)
-- ============================================
-- 
-- MUAMMO: Worker role bilan muammo bor
-- YECHIM: Hozircha barcha userlar uchun default role 'manager' qilish
-- NOTE: Test accountlar (boss@test.com, manager@test.com) o'zgarishsiz qoladi
-- ============================================

-- ============================================
-- STEP 1: MAVJUD USERLARNI YANGILASH
-- ============================================
-- Barcha userlarni 'manager' qilish (test accountlar bundan mustasno)

-- Avval test accountlarni saqlab qolish
-- Boss va Manager test accountlari o'zgarishsiz qoladi

-- Boshqa barcha userlarni 'manager' qilish
UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) NOT IN ('boss@test.com', 'manager@test.com')
  AND (role IS NULL OR role = 'worker' OR role = '');

-- ============================================
-- STEP 2: TRIGGER FUNCTION'NI YANGILASH
-- ============================================
-- Default role 'manager' bo'lsin (test accountlar bundan mustasno)

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
  ELSE
    -- Metadata'da role bo'lmasa, default 'manager' (TEMPORARY)
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
-- STEP 3: DEFAULT VALUE'NI YANGILASH
-- ============================================
-- Role column uchun default value 'manager' qilish (TEMPORARY)

ALTER TABLE public.users
ALTER COLUMN role SET DEFAULT 'manager';

-- ============================================
-- STEP 4: TEKSHIRISH
-- ============================================

DO $$
DECLARE
  manager_count INTEGER;
  worker_count INTEGER;
  boss_count INTEGER;
  total_users INTEGER;
BEGIN
  -- Manager role'li userlarni sanash
  SELECT COUNT(*) INTO manager_count
  FROM public.users
  WHERE role = 'manager';
  
  -- Worker role'li userlarni sanash
  SELECT COUNT(*) INTO worker_count
  FROM public.users
  WHERE role = 'worker';
  
  -- Boss role'li userlarni sanash
  SELECT COUNT(*) INTO boss_count
  FROM public.users
  WHERE role = 'boss';
  
  -- Jami userlar soni
  SELECT COUNT(*) INTO total_users
  FROM public.users;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'ROLE STATISTICS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Manager users: %', manager_count;
  RAISE NOTICE '⚠️ Worker users: %', worker_count;
  RAISE NOTICE '✅ Boss users: %', boss_count;
  RAISE NOTICE '📊 Total users: %', total_users;
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Default role set to MANAGER (TEMPORARY)';
  RAISE NOTICE '✅ Trigger updated - new users will get MANAGER role';
  RAISE NOTICE '✅ Test accounts (boss@test.com, manager@test.com) unchanged';
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Mavjud userlar yangilandi (worker -> manager)
-- ✅ Trigger yangilandi - default role 'manager'
-- ✅ Default value 'manager' o'rnatildi
-- ✅ Test accountlar o'zgarishsiz qoldi
-- ✅ Barcha yangi userlar 'manager' role bilan yaratiladi
--
-- NOTE: Bu vaqtinchalik o'zgarish. Keyin worker role'ni qo'shamiz.














