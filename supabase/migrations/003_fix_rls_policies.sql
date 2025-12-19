-- ============================================
-- STEP 3: Fix Row-Level Security (RLS) Policies
-- ============================================
-- This migration fixes RLS policies for all tables to ensure authenticated users
-- can perform allowed actions based on their role without getting Forbidden errors.
-- 
-- WHY: Previous RLS policies had issues with recursion and role checking.
-- This migration creates safe, non-recursive policies that work correctly.
-- ============================================

-- ============================================
-- 1. USERS TABLE - Fix RLS Policies
-- ============================================

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can read own data" ON users;
DROP POLICY IF EXISTS "Boss can read all users" ON users;
DROP POLICY IF EXISTS "Manager can read department users" ON users;
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Boss can update users" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

-- Policy 1: Users can read ONLY their own profile (non-recursive)
-- WHY: Direct auth.uid() check avoids recursion
CREATE POLICY "Users can read own data" ON users
  FOR SELECT 
  USING (auth.uid() = id);

-- Policy 2: Boss can read all users (non-recursive)
-- WHY: Check role directly from auth.users metadata, not from public.users table
CREATE POLICY "Boss can read all users" ON users
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND (auth.users.raw_user_meta_data->>'role' = 'boss' OR 
           auth.users.raw_user_meta_data->>'role' = 'manager')
    )
  );

-- Policy 3: Manager can read users in their department (non-recursive)
-- WHY: Check manager's department_id from auth.users metadata
CREATE POLICY "Manager can read department users" ON users
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
      AND au.raw_user_meta_data->>'role' = 'manager'
      AND (au.raw_user_meta_data->>'department_id')::uuid = users.department_id
    )
  );

-- Policy 4: Users can insert ONLY their own row (during signup)
-- WHY: Trigger creates the row, but this policy allows it
CREATE POLICY "Users can insert own data" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- Policy 5: Users can update ONLY their own profile
-- WHY: Allow users to update their own name, phone, etc.
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Policy 6: Boss can update any user
-- WHY: Boss needs to manage user roles and departments
CREATE POLICY "Boss can update users" ON users
  FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- 2. PARTS TABLE - Fix RLS Policies
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can read parts" ON parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON parts;

-- Policy 1: All authenticated users can read parts
-- WHY: Everyone needs to see inventory
CREATE POLICY "Authenticated users can read parts" ON parts
  FOR SELECT 
  USING (auth.role() = 'authenticated');

-- Policy 2: Workers, Managers, Boss, and Suppliers can create parts
-- WHY: Non-recursive role check using auth.users metadata
CREATE POLICY "Authorized users can create parts" ON parts
  FOR INSERT 
  WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('worker', 'manager', 'boss', 'supplier')
    )
  );

-- Policy 3: Managers, Boss, and Suppliers can update parts
-- WHY: Allow quantity updates, name changes, etc.
CREATE POLICY "Authorized users can update parts" ON parts
  FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss', 'supplier')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss', 'supplier')
    )
  );

-- Policy 4: Only Boss can delete parts
-- WHY: Prevent accidental deletion of inventory
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
-- 3. PRODUCTS TABLE - Fix RLS Policies
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can read products" ON products;
DROP POLICY IF EXISTS "Managers and boss can manage products" ON products;

-- Policy 1: All authenticated users can read products
-- WHY: Everyone needs to see available products
CREATE POLICY "Authenticated users can read products" ON products
  FOR SELECT 
  USING (auth.role() = 'authenticated');

-- Policy 2: Managers and Boss can create products
-- WHY: Non-recursive role check
CREATE POLICY "Managers and boss can create products" ON products
  FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  );

-- Policy 3: Managers and Boss can update products
-- WHY: Allow product modifications
CREATE POLICY "Managers and boss can update products" ON products
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

-- Policy 4: Only Boss can delete products
-- WHY: Prevent accidental deletion
CREATE POLICY "Boss can delete products" ON products
  FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- 4. ORDERS TABLE - Fix RLS Policies
-- ============================================

-- Ensure orders table exists (if not, create it)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders') THEN
    CREATE TABLE orders (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      product_id UUID NOT NULL REFERENCES products(id),
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      department_id UUID NOT NULL REFERENCES departments(id),
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'rejected')),
      created_by UUID REFERENCES users(id),
      approved_by UUID REFERENCES users(id),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ
    );

    CREATE INDEX idx_orders_status ON orders(status);
    CREATE INDEX idx_orders_department ON orders(department_id);
    CREATE INDEX idx_orders_created_at ON orders(created_at);
  END IF;
END $$;

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can read orders" ON orders;
DROP POLICY IF EXISTS "Authenticated users can create orders" ON orders;
DROP POLICY IF EXISTS "Managers and boss can update orders" ON orders;
DROP POLICY IF EXISTS "Boss can delete orders" ON orders;

-- Policy 1: All authenticated users can read orders
-- WHY: Everyone needs to see order status
CREATE POLICY "Authenticated users can read orders" ON orders
  FOR SELECT 
  USING (auth.role() = 'authenticated');

-- Policy 2: All authenticated users can create orders
-- WHY: Workers need to create orders
CREATE POLICY "Authenticated users can create orders" ON orders
  FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

-- Policy 3: Managers and Boss can update orders (approve/reject)
-- WHY: Non-recursive role check
CREATE POLICY "Managers and boss can update orders" ON orders
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

-- Policy 4: Only Boss can delete orders
-- WHY: Prevent accidental deletion
CREATE POLICY "Boss can delete orders" ON orders
  FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- 5. DEPARTMENTS TABLE - Fix RLS Policies
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can read departments" ON departments;
DROP POLICY IF EXISTS "Managers and boss can manage departments" ON departments;

-- Policy 1: All authenticated users can read departments
-- WHY: Everyone needs to see available departments
CREATE POLICY "Authenticated users can read departments" ON departments
  FOR SELECT 
  USING (auth.role() = 'authenticated');

-- Policy 2: Managers and Boss can create departments
-- WHY: Non-recursive role check
CREATE POLICY "Managers and boss can create departments" ON departments
  FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
    )
  );

-- Policy 3: Managers and Boss can update departments
-- WHY: Allow department name changes
CREATE POLICY "Managers and boss can update departments" ON departments
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

-- Policy 4: Only Boss can delete departments
-- WHY: Prevent accidental deletion
CREATE POLICY "Boss can delete departments" ON departments
  FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' = 'boss'
    )
  );

-- ============================================
-- NOTES:
-- ============================================
-- 1. All policies use auth.users.raw_user_meta_data->>'role' to avoid recursion
-- 2. Policies are non-recursive - they don't query public.users table
-- 3. Role information is stored in auth.users metadata during signup
-- 4. The trigger handle_new_user() copies role from metadata to public.users table
-- 5. For testing: Run this migration in Supabase SQL Editor
-- 6. After migration: Test creating parts/products/orders from the app
-- ============================================













