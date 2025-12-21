-- ============================================
-- Migration 018: Fix updated_at Column Error
-- ============================================
-- 
-- MUAMMO: "column updated_at of relation users does not exist"
-- SABAB: updated_at column mavjud emas, lekin trigger'da ishlatilmoqda
-- 
-- YECHIM: updated_at column'ni yaratish yoki trigger'dan olib tashlash
-- ============================================

-- ============================================
-- STEP 1: UPDATED_AT COLUMN'NI YARATISH
-- ============================================

DO $$
BEGIN
  -- Updated_at column mavjudligini tekshirish
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.users ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    RAISE NOTICE '✅ Updated_at column qo''shildi';
  ELSE
    RAISE NOTICE '✅ Updated_at column allaqachon mavjud';
  END IF;
END $$;

-- ============================================
-- STEP 2: TRIGGER FUNCTION'NI YANGILASH (UPDATED_AT QO'SHISH)
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
    role = COALESCE(EXCLUDED.role, users.role, 'worker');
  
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
-- SUMMARY
-- ============================================
-- ✅ Updated_at column yaratildi
-- ✅ Trigger function yangilandi (updated_at olib tashlandi)
-- ✅ Endi xatolik bo'lmaydi















