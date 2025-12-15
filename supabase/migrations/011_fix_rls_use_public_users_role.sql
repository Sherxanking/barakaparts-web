-- ============================================
-- Migration 011: Fix RLS Policies to Use public.users.role
-- ============================================
-- 
-- WHY: Current RLS policies check auth.users.raw_user_meta_data->>'role'
-- but the role is actually stored in public.users.role table.
-- This migration fixes all policies to check public.users.role correctly.
-- ============================================

-- ============================================
-- 1. DROP EXISTING PARTS POLICIES
-- ============================================
DROP POLICY IF EXISTS "All authenticated users can read parts" ON parts;
DROP POLICY IF EXISTS "Managers and boss can create parts" ON parts;
DROP POLICY IF EXISTS "Managers and boss can update parts" ON parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON parts;

-- ============================================
-- 2. CREATE FIXED RBAC POLICIES FOR PARTS
-- ============================================

-- Policy 1: All authenticated users (Workers, Managers, Boss) can READ parts
-- WHY: Everyone needs to see inventory
CREATE POLICY "All authenticated users can read parts" ON parts
  FOR SELECT 
  USING (auth.role() = 'authenticated');

-- Policy 2: Only Managers and Boss can CREATE parts
-- WHY: Workers are read-only, only managers/boss can add new parts
-- FIX: Check public.users.role instead of auth.users.raw_user_meta_data
CREATE POLICY "Managers and boss can create parts" ON parts
  FOR INSERT 
  WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM public.users
      WHERE public.users.id = auth.uid()
      AND public.users.role IN ('manager', 'boss')
    )
  );

-- Policy 3: Only Managers and Boss can UPDATE parts
-- WHY: Workers cannot modify inventory
-- FIX: Check public.users.role instead of auth.users.raw_user_meta_data
CREATE POLICY "Managers and boss can update parts" ON parts
  FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE public.users.id = auth.uid()
      AND public.users.role IN ('manager', 'boss')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE public.users.id = auth.uid()
      AND public.users.role IN ('manager', 'boss')
    )
  );

-- Policy 4: Only Boss can DELETE parts
-- WHY: Prevent accidental deletion, only boss can delete
-- FIX: Check public.users.role instead of auth.users.raw_user_meta_data
CREATE POLICY "Boss can delete parts" ON parts
  FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE public.users.id = auth.uid()
      AND public.users.role = 'boss'
    )
  );

-- ============================================
-- 3. VERIFY POLICIES
-- ============================================
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'parts';
  
  IF policy_count < 4 THEN
    RAISE EXCEPTION 'Expected 4 policies for parts table, found %', policy_count;
  ELSE
    RAISE NOTICE '✅ Successfully created % policies for parts table', policy_count;
  END IF;
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Workers: SELECT only (read-only access)
-- ✅ Managers & Boss: Full CRUD (INSERT, SELECT, UPDATE, DELETE)
-- ✅ Boss: Can also DELETE parts
-- ✅ All policies now check public.users.role (correct source of truth)




