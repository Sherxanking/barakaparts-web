-- ============================================
-- Migration 016: Fix Missing Users - Trigger Check
-- ============================================
-- 
-- MUAMMO: Login qilganda "User avtomatik yaratilmadi" xatosi
-- SABAB: Trigger ishlamayapti yoki user yaratilganda trigger ishlamagan
-- 
-- YECHIM: 
-- 1. Trigger'ni tekshirish va qayta yaratish
-- 2. Mavjud auth.users da bo'lgan, lekin public.users da yo'q userlarni yaratish
-- ============================================

-- ============================================
-- STEP 1: TRIGGER'NI TEKSHIRISH VA QAYTA YARATISH
-- ============================================

-- Trigger mavjudligini tekshirish
DO $$
DECLARE
  trigger_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'on_auth_user_created'
  ) INTO trigger_exists;
  
  IF NOT trigger_exists THEN
    RAISE NOTICE '⚠️ Trigger mavjud emas, yaratilmoqda...';
    
    -- Trigger'ni yaratish
    CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW
      EXECUTE FUNCTION public.handle_new_user();
    
    RAISE NOTICE '✅ Trigger yaratildi';
  ELSE
    RAISE NOTICE '✅ Trigger mavjud';
  END IF;
END $$;

-- ============================================
-- STEP 2: MAVJUD AUTH.USERS DA BO'LGAN, LEKIN PUBLIC.USERS DA YO'Q USERLARNI YARATISH
-- ============================================

-- Auth.users da bo'lgan, lekin public.users da yo'q userlarni topish va yaratish
INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  au.id,
  COALESCE(
    au.raw_user_meta_data->>'name',
    au.raw_user_meta_data->>'full_name',
    split_part(COALESCE(au.email, ''), '@', 1),
    'User'
  ) as name,
  COALESCE(au.email, '') as email,
  CASE 
    WHEN LOWER(COALESCE(au.email, '')) = 'manager@test.com' THEN 'manager'
    WHEN LOWER(COALESCE(au.email, '')) = 'boss@test.com' THEN 'boss'
    ELSE COALESCE(
      au.raw_user_meta_data->>'role',
      'worker'
    )
  END as role,
  COALESCE(au.created_at, NOW()) as created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL  -- public.users da yo'q
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  role = EXCLUDED.role;

-- ============================================
-- STEP 3: TEKSHIRISH
-- ============================================

DO $$
DECLARE
  missing_count INTEGER;
  total_auth_users INTEGER;
  total_public_users INTEGER;
BEGIN
  -- Auth.users da bo'lgan, lekin public.users da yo'q userlarni sanash
  SELECT COUNT(*) INTO missing_count
  FROM auth.users au
  LEFT JOIN public.users pu ON au.id = pu.id
  WHERE pu.id IS NULL;
  
  -- Jami auth.users soni
  SELECT COUNT(*) INTO total_auth_users FROM auth.users;
  
  -- Jami public.users soni
  SELECT COUNT(*) INTO total_public_users FROM public.users;
  
  IF missing_count > 0 THEN
    RAISE WARNING '⚠️ Hali ham % ta user public.users da yo''q', missing_count;
  ELSE
    RAISE NOTICE '✅ Barcha auth.users public.users da mavjud';
  END IF;
  
  RAISE NOTICE '📊 Statistika:';
  RAISE NOTICE '   Auth users: %', total_auth_users;
  RAISE NOTICE '   Public users: %', total_public_users;
  RAISE NOTICE '   Missing: %', missing_count;
END $$;

-- ============================================
-- STEP 4: TRIGGER FUNCTION'NI YANGILASH (AGAR KERAK BO'LSA)
-- ============================================
-- Bu qism faqat trigger ishlamasa ishlatiladi

-- Function mavjudligini tekshirish
DO $$
DECLARE
  function_exists BOOLEAN;
  is_security_definer BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'handle_new_user'
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  ) INTO function_exists;
  
  IF function_exists THEN
    -- SECURITY DEFINER ekanligini tekshirish
    SELECT prosecdef INTO is_security_definer
    FROM pg_proc
    WHERE proname = 'handle_new_user'
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
    
    IF NOT is_security_definer THEN
      RAISE WARNING '⚠️ Function SECURITY DEFINER emas! Migration 015 ni qo''llash kerak.';
    ELSE
      RAISE NOTICE '✅ Function mavjud va SECURITY DEFINER';
    END IF;
  ELSE
    RAISE EXCEPTION '❌ Function handle_new_user mavjud emas! Migration 015 ni qo''llash kerak.';
  END IF;
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Trigger tekshirildi va qayta yaratildi (agar kerak bo'lsa)
-- ✅ Mavjud auth.users da bo'lgan, lekin public.users da yo'q userlar yaratildi
-- ✅ Barcha userlar endi public.users da mavjud
-- ✅ Trigger endi ishlaydi va yangi userlar avtomatik yaratiladi

