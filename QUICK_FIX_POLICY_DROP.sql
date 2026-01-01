-- ============================================
-- QUICK FIX: Drop existing policies that may conflict
-- ============================================
-- 
-- Bu faylni FINAL_COMPLETE_FIX.sql dan OLDIN bajarish kerak
-- yoki FINAL_COMPLETE_FIX.sql ni qayta bajarish kerak
-- ============================================

-- Drop all existing users policies
DROP POLICY IF EXISTS "Users read self" ON public.users;
DROP POLICY IF EXISTS "Boss read all users" ON public.users;
DROP POLICY IF EXISTS "Boss can read all users" ON public.users;
DROP POLICY IF EXISTS "Manager read all users" ON public.users;
DROP POLICY IF EXISTS "Manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Boss can update users" ON public.users;
DROP POLICY IF EXISTS "Boss can update all users" ON public.users;
DROP POLICY IF EXISTS "Boss update all users" ON public.users;

-- Drop all existing parts policies
DROP POLICY IF EXISTS "All authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can create parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can update parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON public.parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can delete parts" ON public.parts;

-- ============================================
-- ✅ DROP COMPLETE
-- ============================================
-- Endi FINAL_COMPLETE_FIX.sql ni bajarishingiz mumkin
-- ============================================






























