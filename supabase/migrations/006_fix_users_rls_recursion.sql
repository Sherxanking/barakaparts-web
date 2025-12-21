-- ============================================
-- Migration 006: Fix Infinite Recursion in Users RLS Policies
-- ============================================
-- 
-- WHY: The previous RLS policies on users table were causing infinite recursion
-- because they referenced the users table itself during INSERT operations.
-- 
-- SOLUTION: Use ONLY auth.uid() and auth.users metadata (NOT public.users table)
-- to break the recursion cycle.
-- ============================================

-- ============================================
-- STEP 1: Disable ALL existing RLS policies on users
-- ============================================

-- Drop ALL existing policies on users table
DROP POLICY IF EXISTS "Users can read own data" ON users;
DROP POLICY IF EXISTS "Boss can read all users" ON users;
DROP POLICY IF EXISTS "Manager can read department users" ON users;
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;
DROP POLICY IF EXISTS "Boss can update users" ON users;
DROP POLICY IF EXISTS "Managers and boss can create users" ON users;
DROP POLICY IF EXISTS "Managers and boss can update users" ON users;
DROP POLICY IF EXISTS "Boss can delete users" ON users;

-- ============================================
-- STEP 2: Re-enable RLS with SAFE policies
-- ============================================

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- ============================================
-- POLICY 1: User can read ONLY their own profile
-- ============================================
-- WHY: Uses auth.uid() directly - NO table reference = NO recursion
CREATE POLICY "Users can read own data" ON users
  FOR SELECT 
  USING (auth.uid() = id);

-- ============================================
-- POLICY 2: Boss & Manager can read everyone
-- ============================================
-- WHY: Uses auth.users metadata (NOT public.users) - NO recursion
CREATE POLICY "Boss and manager can read all users" ON users
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND (
        auth.users.raw_user_meta_data->>'role' = 'boss' OR
        auth.users.raw_user_meta_data->>'role' = 'manager'
      )
    )
  );

-- ============================================
-- POLICY 3: User can insert ONLY their own row
-- ============================================
-- WHY: Uses auth.uid() directly - NO table reference = NO recursion
-- This allows registration to work!
CREATE POLICY "Users can insert own data" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- ============================================
-- POLICY 4: User can update ONLY their own row
-- ============================================
-- WHY: Uses auth.uid() directly - NO table reference = NO recursion
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================
-- POLICY 5: Boss can update any user
-- ============================================
-- WHY: Uses auth.users metadata (NOT public.users) - NO recursion
CREATE POLICY "Boss can update users" ON users
  FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- VERIFICATION
-- ============================================
-- After running this migration, test:
-- 1. User registration should work (no recursion error)
-- 2. User can read their own profile
-- 3. Boss can read all users
-- 4. User can update their own profile
-- 5. Boss can update any user


















