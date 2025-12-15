-- ============================================
-- Migration 005: Drop All Policies and Recreate
-- ============================================
-- 
-- WHY: This migration drops ALL existing RLS policies and recreates them
-- Use this if you get "policy already exists" errors from previous migrations
-- 
-- SAFE TO RUN: This will drop and recreate all policies cleanly
-- ============================================

-- ============================================
-- 1. DROP ALL POLICIES ON ALL TABLES
-- ============================================

-- Drop all policies on users table
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'users') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON users';
  END LOOP;
END $$;

-- Drop all policies on parts table
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'parts') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON parts';
  END LOOP;
END $$;

-- Drop all policies on products table
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'products') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON products';
  END LOOP;
END $$;

-- Drop all policies on orders table
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'orders') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON orders';
  END LOOP;
END $$;

-- Drop all policies on departments table
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'departments') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON departments';
  END LOOP;
END $$;

-- ============================================
-- 2. RECREATE ALL POLICIES (from migration 004)
-- ============================================

-- ============================================
-- USERS TABLE POLICIES
-- ============================================
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Boss can read all users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND (auth.users.raw_user_meta_data->>'role' = 'boss' OR 
           auth.users.raw_user_meta_data->>'role' = 'manager')
    )
  );

CREATE POLICY "Manager can read department users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND au.raw_user_meta_data->>'role' = 'manager'
      AND (au.raw_user_meta_data->>'department_id')::uuid = users.department_id
    )
  );

CREATE POLICY "Users can insert own data" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own data" ON users
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "Boss can update users" ON users
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- PARTS TABLE POLICIES
-- ============================================
CREATE POLICY "Authenticated users can read parts" ON parts
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authorized users can create parts" ON parts
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('worker', 'manager', 'boss', 'supplier')
    )
  );

CREATE POLICY "Authorized users can update parts" ON parts
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss', 'supplier')
    )
  );

CREATE POLICY "Boss can delete parts" ON parts
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- PRODUCTS TABLE POLICIES
-- ============================================
CREATE POLICY "Authenticated users can read products" ON products
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can create products" ON products
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  );

CREATE POLICY "Managers and boss can update products" ON products
  FOR UPDATE USING (
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

CREATE POLICY "Boss can delete products" ON products
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- ORDERS TABLE POLICIES
-- ============================================
CREATE POLICY "Authenticated users can read orders" ON orders
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create orders" ON orders
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can update orders" ON orders
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  );

CREATE POLICY "Boss can delete orders" ON orders
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- DEPARTMENTS TABLE POLICIES
-- ============================================
CREATE POLICY "Authenticated users can read departments" ON departments
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can create departments" ON departments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  );

CREATE POLICY "Managers and boss can update departments" ON departments
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  );

CREATE POLICY "Boss can delete departments" ON departments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- SUMMARY
-- ============================================
-- This migration:
-- ✅ Drops ALL existing policies on all tables
-- ✅ Recreates all policies cleanly
-- ✅ Safe to run multiple times
-- ✅ Fixes "policy already exists" errors
-- ============================================









