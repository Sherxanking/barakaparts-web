-- ============================================
-- Migration 015: Fix Role for Dashboard-Created Users (FIXED)
-- ============================================
-- 
-- MUAMMO: Supabase Dashboard orqali yangi user yaratilganda role yo'qolmoqda
-- SABAB: Dashboard orqali yaratilganda metadata'da role bo'lmasligi mumkin
-- 
-- YECHIM: 
-- 1. Avval test accountlarni to'g'ri sozlash
-- 2. Keyin boshqa userlarni yangilash
-- 3. Trigger'ni yangilash - metadata'da role bo'lmasa default 'worker' o'rnatish
-- ============================================

-- ============================================
-- STEP 1: TEST ACCOUNTLARNI AVVAL TO'G'RI SOZLASH
-- ============================================
-- FIX: Test accountlarni AVVAL yangilash, keyin boshqalarni
-- WHY: Test accountlar invalid role bo'lsa ham to'g'ri role o'rnatilishi kerak

-- Manager test account
UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com';

-- Boss test account
UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com';

-- ============================================
-- STEP 2: BOSHQA USERLARNI YANGILASH
-- ============================================
-- Role NULL yoki yo'q bo'lgan userlarni 'worker' bilan yangilash
-- FIX: Test accountlarni exclude qilish

UPDATE public.users
SET role = 'worker'
WHERE (role IS NULL 
   OR role = ''
   OR role NOT IN ('worker', 'manager', 'boss'))
   AND LOWER(email) NOT IN ('manager@test.com', 'boss@test.com');

-- ============================================
-- STEP 3: TRIGGER FUNCTION'NI YANGILASH
-- ============================================
-- FIX: Metadata'da role bo'lmasa ham to'g'ri role o'rnatish

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
  -- FIX: Test accountlar uchun validatsiyani o'tkazib yuborish
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
-- STEP 4: ROLE COLUMN'NI NOT NULL QILISH
-- ============================================
-- Role har doim bo'lishi kerak

-- Avval NULL bo'lgan role'larni 'worker' bilan to'ldirish (test accountlarni exclude)
UPDATE public.users
SET role = 'worker'
WHERE role IS NULL
  AND LOWER(email) NOT IN ('manager@test.com', 'boss@test.com');

-- Test accountlarni yana bir bor tekshirish
UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com' AND role IS NULL;

UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com' AND role IS NULL;

-- Keyin NOT NULL constraint qo'shish
ALTER TABLE public.users
ALTER COLUMN role SET NOT NULL;

-- Default value'ni ta'minlash
ALTER TABLE public.users
ALTER COLUMN role SET DEFAULT 'worker';

-- ============================================
-- STEP 5: TEKSHIRISH
-- ============================================

DO $$
DECLARE
  null_role_count INTEGER;
  invalid_role_count INTEGER;
  total_users INTEGER;
  boss_count INTEGER;
  manager_count INTEGER;
BEGIN
  -- NULL role'li userlarni tekshirish
  SELECT COUNT(*) INTO null_role_count
  FROM public.users
  WHERE role IS NULL;
  
  -- Invalid role'li userlarni tekshirish
  SELECT COUNT(*) INTO invalid_role_count
  FROM public.users
  WHERE role NOT IN ('worker', 'manager', 'boss');
  
  -- Jami userlar soni
  SELECT COUNT(*) INTO total_users
  FROM public.users;
  
  -- Boss test accountni tekshirish
  SELECT COUNT(*) INTO boss_count
  FROM public.users
  WHERE LOWER(email) = 'boss@test.com' AND role = 'boss';
  
  -- Manager test accountni tekshirish
  SELECT COUNT(*) INTO manager_count
  FROM public.users
  WHERE LOWER(email) = 'manager@test.com' AND role = 'manager';
  
  IF null_role_count > 0 THEN
    RAISE WARNING '⚠️ Hali ham % ta user role NULL', null_role_count;
  ELSE
    RAISE NOTICE '✅ Barcha userlar role ga ega';
  END IF;
  
  IF invalid_role_count > 0 THEN
    RAISE WARNING '⚠️ Hali ham % ta user invalid role ga ega', invalid_role_count;
  ELSE
    RAISE NOTICE '✅ Barcha userlar valid role ga ega';
  END IF;
  
  IF boss_count = 0 THEN
    RAISE WARNING '⚠️ boss@test.com to''g''ri role ga ega emas!';
  ELSE
    RAISE NOTICE '✅ boss@test.com to''g''ri role ga ega (boss)';
  END IF;
  
  IF manager_count = 0 THEN
    RAISE WARNING '⚠️ manager@test.com to''g''ri role ga ega emas!';
  ELSE
    RAISE NOTICE '✅ manager@test.com to''g''ri role ga ega (manager)';
  END IF;
  
  RAISE NOTICE '✅ Jami userlar: %', total_users;
  RAISE NOTICE '✅ Trigger yangilandi! Endi barcha yangi userlar role ga ega bo''ladi.';
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Test accountlar AVVAL to'g'ri sozlandi
-- ✅ Boshqa userlar keyin yangilandi
-- ✅ Trigger yangilandi - test accountlar uchun maxsus tekshiruv
-- ✅ Role column NOT NULL qilindi
-- ✅ Default value 'worker' o'rnatildi
-- ✅ boss@test.com va manager@test.com to'g'ri role ga ega bo'ladi















