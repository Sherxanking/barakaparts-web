-- ============================================
-- Fix Parts Realtime + RLS Policies
-- ============================================
-- WHY: Enables realtime for parts table and fixes RLS policies
-- Ensures proper role-based access control

-- ============================================
-- 1. ENABLE REALTIME FOR PARTS TABLE
-- ============================================
-- Enable realtime publication for parts table
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS parts;

-- ============================================
-- 2. DROP ALL EXISTING PARTS POLICIES
-- ============================================
-- Drop all existing policies to recreate them correctly
DROP POLICY IF EXISTS "All authenticated users can read parts" ON parts;
DROP POLICY IF EXISTS "Authenticated users can read parts" ON parts;
DROP POLICY IF EXISTS "Managers and boss can create parts" ON parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON parts;
DROP POLICY IF EXISTS "Managers and boss can update parts" ON parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON parts;
DROP POLICY IF EXISTS "Managers and boss can delete parts" ON parts;

-- ============================================
-- 3. CREATE CORRECT RLS POLICIES
-- ============================================

-- Policy 1: SELECT - All authenticated users can read parts
-- WHY: Everyone needs to see inventory
CREATE POLICY "All authenticated users can read parts" ON parts
  FOR SELECT 
  USING (auth.role() = 'authenticated');

-- Policy 2: INSERT - Only managers and boss can create parts
-- WHY: Workers are read-only, only managers/boss can add new parts
-- Logic: Check if user role is manager or boss in users table
CREATE POLICY "Managers and boss can create parts" ON parts
  FOR INSERT 
  WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('manager', 'boss')
    )
  );

-- Policy 3: UPDATE - Only managers and boss can update parts
-- WHY: Workers cannot modify inventory
-- Logic: Check if user role is manager or boss, OR if user is the creator
CREATE POLICY "Managers and boss can update parts" ON parts
  FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('manager', 'boss')
    )
    OR (
      created_by IS NOT NULL 
      AND created_by = auth.uid()
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role IN ('manager', 'boss')
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('manager', 'boss')
    )
    OR (
      created_by IS NOT NULL 
      AND created_by = auth.uid()
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role IN ('manager', 'boss')
      )
    )
  );

-- Policy 4: DELETE - Only managers and boss can delete parts
-- WHY: Prevent accidental deletion, only managers/boss can delete
CREATE POLICY "Managers and boss can delete parts" ON parts
  FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('manager', 'boss')
    )
  );

-- ============================================
-- 4. VERIFY POLICIES
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
-- ✅ Realtime enabled for parts table
-- ✅ SELECT: All authenticated users
-- ✅ INSERT: Only managers and boss
-- ✅ UPDATE: Only managers and boss
-- ✅ DELETE: Only managers and boss
-- ✅ All policies use users.role column for role checking



































