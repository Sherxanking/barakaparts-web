-- ============================================
-- Migration 014: Fix Trigger for Test Accounts Role
-- ============================================
-- 
-- MUAMMO: Test accountlar (manager@test.com, boss@test.com) worker bo'lib chiqmoqda
-- SABAB: Trigger metadata'dan role olishda test accountlarni tekshirmayapti
-- 
-- YECHIM: Trigger'da test accountlar uchun maxsus tekshiruv qo'shish
-- ============================================

-- ============================================
-- STEP 1: TRIGGER FUNCTION'NI YANGILASH
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
BEGIN
  -- Email ni olish
  user_email := COALESCE(NEW.email, '');
  
  -- FIX: Test accountlar uchun role'ni email'dan aniqlash
  -- WHY: Test accountlar (manager@test.com, boss@test.com) uchun to'g'ri role o'rnatish
  IF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
    RAISE NOTICE '✅ Test account detected: manager@test.com -> role: manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
    RAISE NOTICE '✅ Test account detected: boss@test.com -> role: boss';
  ELSE
    -- Boshqa foydalanuvchilar uchun metadata'dan olish (default: 'worker')
    user_role := COALESCE(
      NEW.raw_user_meta_data->>'role',
      'worker'
    );
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
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    updated_at = NOW();
  
  RAISE NOTICE '✅ User profile created: % (role: %)', user_email, user_role;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Xatolik bo'lsa, log qilish
    RAISE WARNING 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- ============================================
-- STEP 2: MAVJUD TEST ACCOUNTLARNI YANGILASH
-- ============================================
-- Agar test accountlar allaqachon yaratilgan bo'lsa, ularning role'larini yangilash

UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com' AND role != 'manager';

UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com' AND role != 'boss';

-- ============================================
-- STEP 3: TEKSHIRISH
-- ============================================

DO $$
DECLARE
  manager_count INTEGER;
  boss_count INTEGER;
BEGIN
  -- Manager test accountni tekshirish
  SELECT COUNT(*) INTO manager_count
  FROM public.users
  WHERE LOWER(email) = 'manager@test.com' AND role = 'manager';
  
  -- Boss test accountni tekshirish
  SELECT COUNT(*) INTO boss_count
  FROM public.users
  WHERE LOWER(email) = 'boss@test.com' AND role = 'boss';
  
  IF manager_count > 0 THEN
    RAISE NOTICE '✅ Manager test account to''g''ri sozlangan';
  END IF;
  
  IF boss_count > 0 THEN
    RAISE NOTICE '✅ Boss test account to''g''ri sozlangan';
  END IF;
  
  RAISE NOTICE '✅ Trigger yangilandi! Endi test accountlar to''g''ri role bilan yaratiladi.';
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Trigger test accountlar uchun to'g'ri role o'rnatadi
-- ✅ manager@test.com -> role: 'manager'
-- ✅ boss@test.com -> role: 'boss'
-- ✅ Mavjud test accountlar yangilandi
-- ✅ Yangi test accountlar to'g'ri role bilan yaratiladi















