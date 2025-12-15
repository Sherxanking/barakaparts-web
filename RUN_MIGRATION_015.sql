-- ============================================
-- Migration 015: Fix Role for Dashboard-Created Users
-- ============================================
-- 
-- MUAMMO: Supabase Dashboard orqali yangi user yaratilganda role yo'qolmoqda
-- SABAB: Dashboard orqali yaratilganda metadata'da role bo'lmasligi mumkin
-- 
-- YECHIM: 
-- 1. Trigger'ni yangilash - metadata'da role bo'lmasa default 'worker' o'rnatish
-- 2. Mavjud userlarni yangilash - role NULL yoki yo'q bo'lsa 'worker' o'rnatish
-- ============================================

-- ============================================
-- STEP 1: MAVJUD USERLARNI YANGILASH
-- ============================================
-- Role NULL yoki yo'q bo'lgan userlarni 'worker' bilan yangilash

UPDATE public.users
SET role = 'worker'
WHERE role IS NULL 
   OR role = ''
   OR role NOT IN ('worker', 'manager', 'boss');

-- Test accountlarni to'g'ri sozlash
UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com' 
  AND (role IS NULL OR role != 'manager');

UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com' 
  AND (role IS NULL OR role != 'boss');

-- ============================================
-- STEP 2: TRIGGER FUNCTION'NI YANGILASH
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
    -- Metadata'da role bo'lmasa, default 'worker'
    user_role := 'worker';
    RAISE NOTICE '⚠️ No role in metadata, using default: worker';
  END IF;
  
  -- Role validatsiyasi (faqat ruxsat etilgan rollar)
  IF user_role NOT IN ('worker', 'manager', 'boss') THEN
    user_role := 'worker';
    RAISE WARNING 'Invalid role detected, using default: worker';
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
    role = COALESCE(EXCLUDED.role, users.role, 'worker'), -- FIX: Role yo'q bo'lsa 'worker'
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
-- STEP 3: ROLE COLUMN'NI NOT NULL QILISH
-- ============================================
-- Role har doim bo'lishi kerak

-- Avval NULL bo'lgan role'larni 'worker' bilan to'ldirish
UPDATE public.users
SET role = 'worker'
WHERE role IS NULL;

-- Keyin NOT NULL constraint qo'shish
ALTER TABLE public.users
ALTER COLUMN role SET NOT NULL;

-- Default value'ni ta'minlash
ALTER TABLE public.users
ALTER COLUMN role SET DEFAULT 'worker';

-- ============================================
-- STEP 4: TEKSHIRISH
-- ============================================

DO $$
DECLARE
  null_role_count INTEGER;
  invalid_role_count INTEGER;
  total_users INTEGER;
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
  
  RAISE NOTICE '✅ Jami userlar: %', total_users;
  RAISE NOTICE '✅ Trigger yangilandi! Endi barcha yangi userlar role ga ega bo''ladi.';
END $$;

-- ============================================
-- STEP 5: MAVJUD USERLARNI YANGILASH (AGAR KERAK BO'LSA)
-- ============================================
-- Bu qismni faqat kerak bo'lsa ishlatish

-- Barcha userlarni tekshirish va role o'rnatish
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT id, email, role 
    FROM public.users 
    WHERE role IS NULL 
       OR role = '' 
       OR role NOT IN ('worker', 'manager', 'boss')
  LOOP
    -- Test accountlarni tekshirish
    IF LOWER(user_record.email) = 'manager@test.com' THEN
      UPDATE public.users SET role = 'manager' WHERE id = user_record.id;
      RAISE NOTICE 'Updated user % to role: manager', user_record.email;
    ELSIF LOWER(user_record.email) = 'boss@test.com' THEN
      UPDATE public.users SET role = 'boss' WHERE id = user_record.id;
      RAISE NOTICE 'Updated user % to role: boss', user_record.email;
    ELSE
      -- Boshqa userlar uchun default 'worker'
      UPDATE public.users SET role = 'worker' WHERE id = user_record.id;
      RAISE NOTICE 'Updated user % to role: worker', user_record.email;
    END IF;
  END LOOP;
END $$;




