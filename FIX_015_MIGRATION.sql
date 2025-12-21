-- ============================================
-- FIX: Migration 015 Xatoliklarini Tuzatish
-- ============================================
-- 
-- MUAMMO: Migration 015 ishlamayapti
-- EHTIMOLIY SABABLAR:
-- 1. role column'da hali ham NULL qiymatlar bor
-- 2. NOT NULL constraint qo'shishdan oldin NULL'larni to'ldirish kerak
-- 3. Trigger function'da xatolik
-- 
-- YECHIM: Xavfsiz, bosqichma-bosqich yechim
-- ============================================

-- ============================================
-- STEP 1: Barcha NULL role'larni to'ldirish
-- ============================================
-- Avval test accountlarni to'g'ri sozlash
UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com' AND (role IS NULL OR role = '');

UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com' AND (role IS NULL OR role = '');

-- Keyin boshqa userlarni 'worker' bilan to'ldirish
UPDATE public.users
SET role = 'worker'
WHERE (role IS NULL OR role = '')
  AND LOWER(email) NOT IN ('manager@test.com', 'boss@test.com');

-- Invalid role'larni tuzatish
UPDATE public.users
SET role = 'worker'
WHERE role NOT IN ('worker', 'manager', 'boss', 'supplier')
  AND LOWER(email) NOT IN ('manager@test.com', 'boss@test.com');

-- Test accountlarni yana bir bor tekshirish va tuzatish
UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com' AND role != 'manager';

UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com' AND role != 'boss';

-- ============================================
-- STEP 2: Role column'ni NOT NULL qilish (XAVFSIZ)
-- ============================================
-- Avval NULL bo'lgan barcha qiymatlarni tekshirish
DO $$
DECLARE
  null_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO null_count
  FROM public.users
  WHERE role IS NULL;
  
  IF null_count > 0 THEN
    RAISE WARNING '⚠️ Hali ham % ta user role NULL. Avval to''ldirish kerak!', null_count;
    -- NULL'larni to'ldirish
    UPDATE public.users
    SET role = 'worker'
    WHERE role IS NULL
      AND LOWER(email) NOT IN ('manager@test.com', 'boss@test.com');
    
    UPDATE public.users
    SET role = 'manager'
    WHERE role IS NULL AND LOWER(email) = 'manager@test.com';
    
    UPDATE public.users
    SET role = 'boss'
    WHERE role IS NULL AND LOWER(email) = 'boss@test.com';
    
    RAISE NOTICE '✅ NULL role''lar to''ldirildi';
  ELSE
    RAISE NOTICE '✅ Barcha userlar role ga ega';
  END IF;
END $$;

-- Endi NOT NULL constraint qo'shish (agar hali qo'shilmagan bo'lsa)
DO $$
BEGIN
  -- Column'ning NOT NULL ekanligini tekshirish
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'role' 
    AND is_nullable = 'YES'
  ) THEN
    -- Agar hali NOT NULL bo'lmasa, qo'shish
    ALTER TABLE public.users
    ALTER COLUMN role SET NOT NULL;
    
    RAISE NOTICE '✅ Role column NOT NULL qilindi';
  ELSE
    RAISE NOTICE '✅ Role column allaqachon NOT NULL';
  END IF;
  
  -- Default value'ni tekshirish va qo'shish
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'role' 
    AND column_default IS NOT NULL
  ) THEN
    ALTER TABLE public.users
    ALTER COLUMN role SET DEFAULT 'worker';
    
    RAISE NOTICE '✅ Role column default value qo''shildi: worker';
  ELSE
    RAISE NOTICE '✅ Role column allaqachon default value ga ega';
  END IF;
END $$;

-- ============================================
-- STEP 3: Trigger Function'ni Yangilash (XAVFSIZ)
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
  
  -- Test accountlar uchun role'ni email'dan aniqlash
  IF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF metadata_role IS NOT NULL AND metadata_role != '' THEN
    user_role := metadata_role;
  ELSE
    user_role := 'worker';
  END IF;
  
  -- Role validatsiyasi
  IF user_role NOT IN ('worker', 'manager', 'boss', 'supplier') THEN
    IF LOWER(user_email) = 'manager@test.com' THEN
      user_role := 'manager';
    ELSIF LOWER(user_email) = 'boss@test.com' THEN
      user_role := 'boss';
    ELSE
      user_role := 'worker';
    END IF;
  END IF;
  
  -- Name ni olish
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  -- public.users jadvaliga INSERT qilish
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
    name = COALESCE(EXCLUDED.name, public.users.name),
    email = COALESCE(EXCLUDED.email, public.users.email),
    role = CASE 
      WHEN LOWER(EXCLUDED.email) = 'manager@test.com' THEN 'manager'
      WHEN LOWER(EXCLUDED.email) = 'boss@test.com' THEN 'boss'
      ELSE COALESCE(EXCLUDED.role, public.users.role, 'worker')
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
-- STEP 4: Trigger'ni Tekshirish va Yangilash
-- ============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 5: Tekshirish
-- ============================================
DO $$
DECLARE
  null_count INTEGER;
  invalid_count INTEGER;
  total_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO null_count
  FROM public.users
  WHERE role IS NULL;
  
  SELECT COUNT(*) INTO invalid_count
  FROM public.users
  WHERE role NOT IN ('worker', 'manager', 'boss', 'supplier');
  
  SELECT COUNT(*) INTO total_count
  FROM public.users;
  
  IF null_count > 0 THEN
    RAISE WARNING '⚠️ Hali ham % ta user role NULL', null_count;
  ELSE
    RAISE NOTICE '✅ Barcha userlar role ga ega';
  END IF;
  
  IF invalid_count > 0 THEN
    RAISE WARNING '⚠️ Hali ham % ta user invalid role ga ega', invalid_count;
  ELSE
    RAISE NOTICE '✅ Barcha userlar valid role ga ega';
  END IF;
  
  RAISE NOTICE '✅ Jami userlar: %', total_count;
  RAISE NOTICE '✅ Migration 015 tuzatildi!';
END $$;















