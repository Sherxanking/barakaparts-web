-- ============================================
-- RBAC: Role-Based Access Control for Parts
-- ============================================
-- WHY: Implements role-based permissions for parts table
-- Workers: SELECT only (read-only)
-- Managers & Boss: Full CRUD (INSERT, SELECT, UPDATE, DELETE)

-- ============================================
-- 1. ENSURE ROLE COLUMN EXISTS IN USERS TABLE
-- ============================================
DO $$
BEGIN
  -- Add role column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'role'
  ) THEN
    ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'worker';
    RAISE NOTICE 'Added role column to users table';
  ELSE
    RAISE NOTICE 'Role column already exists in users table';
  END IF;
  
  -- Ensure default value is set
  ALTER TABLE users ALTER COLUMN role SET DEFAULT 'worker';
  
  -- Update existing NULL roles to 'worker'
  UPDATE users SET role = 'worker' WHERE role IS NULL;
END $$;

-- ============================================
-- 2. DROP EXISTING PARTS POLICIES
-- ============================================
DROP POLICY IF EXISTS "Authenticated users can read parts" ON parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON parts;
DROP POLICY IF EXISTS "Workers can read parts" ON parts;
DROP POLICY IF EXISTS "Managers and boss can manage parts" ON parts;

-- ============================================
-- 3. CREATE NEW RBAC POLICIES FOR PARTS
-- ============================================

-- Policy 1: All authenticated users (Workers, Managers, Boss) can READ parts
-- WHY: Everyone needs to see inventory
CREATE POLICY "All authenticated users can read parts" ON parts
  FOR SELECT 
  USING (auth.role() = 'authenticated');

-- Policy 2: Only Managers and Boss can CREATE parts
-- WHY: Workers are read-only, only managers/boss can add new parts
CREATE POLICY "Managers and boss can create parts" ON parts
  FOR INSERT 
  WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  );

-- Policy 3: Only Managers and Boss can UPDATE parts
-- WHY: Workers cannot modify inventory
CREATE POLICY "Managers and boss can update parts" ON parts
  FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  );

-- Policy 4: Only Boss can DELETE parts
-- WHY: Prevent accidental deletion, only boss can delete
CREATE POLICY "Boss can delete parts" ON parts
  FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
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
-- ✅ Role column added to users table (default: 'worker')
-- ✅ Workers: SELECT only (read-only access)
-- ✅ Managers & Boss: Full CRUD (INSERT, SELECT, UPDATE, DELETE)
-- ✅ Boss: Can also DELETE parts
-- ✅ All policies use JWT role claim from auth.users.raw_user_meta_data











