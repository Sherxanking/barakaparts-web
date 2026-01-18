-- ============================================
-- Migration 1002: Add Users Trigger
-- ============================================
-- 
-- GOAL: Auth user yaratilganda avtomatik public.users ga qo'shish
-- 
-- ============================================

-- Function: Auth user yaratilganda public.users ga qo'shish
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role TEXT;
  user_name TEXT;
  user_email TEXT;
BEGIN
  user_email := COALESCE(NEW.email, '');
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', '');
  
  -- Auto-detect role by email (optional)
  IF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF user_role = '' OR user_role IS NULL THEN
    user_role := 'worker';
  END IF;
  
  -- Get name from metadata or email
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  -- Insert or update user
  INSERT INTO public.users (id, name, email, role, created_at, updated_at)
  VALUES (NEW.id, user_name, user_email, user_role, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE
  SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    updated_at = NOW();
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- ✅ USERS TRIGGER COMPLETE
-- ============================================
-- 
-- This migration:
-- 1. ✅ Creates handle_new_user() function
-- 2. ✅ Creates trigger on auth.users
-- 3. ✅ Auto-detects role by email (optional)
-- 4. ✅ Works with existing RLS policies
-- 
-- Next steps:
-- 1. Test by creating a new user in Supabase Auth
-- 2. Verify user appears in public.users table
-- ============================================























