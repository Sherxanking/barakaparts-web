-- ============================================
-- Migration 012: Fix Trigger RLS Bypass for User Creation
-- ============================================
-- 
-- WHY: "Database error creating new user" xatosi trigger'ning RLS siyosatlarini
-- o'tkazib yuborishga ruxsat berilmaganligi sababli yuzaga kelmoqda.
-- 
-- MUAMMO: handle_new_user() trigger'i auth.users ga INSERT bo'lganda
-- public.users ga yozishga harakat qiladi, lekin RLS siyosati bloklaydi.
-- 
-- YECHIM: Trigger'ni SECURITY DEFINER qilish yoki service_role kontekstida ishlatish
-- ============================================

-- ============================================
-- 1. DROP EXISTING TRIGGER AND FUNCTION
-- ============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- ============================================
-- 2. CREATE FIXED TRIGGER FUNCTION
-- ============================================
-- FIX: SECURITY DEFINER - trigger RLS'ni o'tkazib yuboradi
-- WHY: Trigger auth.users dan public.users ga yozish uchun RLS'ni o'tkazib yuborishi kerak
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
  -- Get role from metadata (default to 'worker' if not set)
  user_role := COALESCE(
    NEW.raw_user_meta_data->>'role',
    'worker'
  );
  
  -- Get name from metadata
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(NEW.email, '@', 1),
    'User'
  );
  
  -- Get email
  user_email := COALESCE(NEW.email, '');
  
  -- Insert into public.users table
  -- SECURITY DEFINER allows this to bypass RLS
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
    role = EXCLUDED.role;
  
  RETURN NEW;
END;
$$;

-- ============================================
-- 3. CREATE TRIGGER
-- ============================================
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 4. VERIFY TRIGGER EXISTS
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'on_auth_user_created'
  ) THEN
    RAISE EXCEPTION 'Trigger on_auth_user_created was not created!';
  ELSE
    RAISE NOTICE '✅ Trigger on_auth_user_created created successfully';
  END IF;
END $$;

-- ============================================
-- 5. VERIFY FUNCTION EXISTS
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'handle_new_user'
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  ) THEN
    RAISE EXCEPTION 'Function handle_new_user was not created!';
  ELSE
    RAISE NOTICE '✅ Function handle_new_user created successfully';
  END IF;
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Trigger SECURITY DEFINER bilan yaratildi
-- ✅ Trigger RLS'ni o'tkazib yuboradi
-- ✅ Yangi foydalanuvchi yaratilganda avtomatik public.users ga yoziladi
-- ✅ Role metadata'dan olinadi (default: 'worker')
-- ✅ ON CONFLICT bilan xavfsiz (agar allaqachon mavjud bo'lsa, yangilanadi)




