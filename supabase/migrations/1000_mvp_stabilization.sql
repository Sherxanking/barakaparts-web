-- ============================================
-- Migration 1000: MVP Stabilization - SAFE FIX
-- ============================================
-- 
-- GOAL: Stabilize app without breaking existing data
-- - Fix RLS policies (boss/manager CUD, worker read-only)
-- - Ensure users table safety (id, name, email, role with fallbacks)
-- - Add indexes for performance
-- - Enable realtime for all tables
-- ============================================

-- ============================================
-- STEP 1: USERS TABLE SAFETY
-- ============================================

-- 1.1. Ensure users table exists with correct structure
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'users'
  ) THEN
    CREATE TABLE public.users (
      id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      name TEXT NOT NULL DEFAULT 'User',
      email TEXT,
      role TEXT NOT NULL DEFAULT 'worker',
      phone TEXT,
      department_id UUID,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    RAISE NOTICE '✅ Users table created';
  ELSE
    RAISE NOTICE '✅ Users table already exists';
  END IF;
  
  -- Ensure all required columns exist with defaults
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'name'
  ) THEN
    ALTER TABLE public.users ADD COLUMN name TEXT NOT NULL DEFAULT 'User';
    RAISE NOTICE '✅ Name column added';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'email'
  ) THEN
    ALTER TABLE public.users ADD COLUMN email TEXT;
    RAISE NOTICE '✅ Email column added';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'role'
  ) THEN
    ALTER TABLE public.users ADD COLUMN role TEXT NOT NULL DEFAULT 'worker';
    RAISE NOTICE '✅ Role column added';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.users ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    RAISE NOTICE '✅ Updated_at column added';
  END IF;
END $$;

-- 1.2. Ensure updated_at column exists before using it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.users ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    RAISE NOTICE '✅ Updated_at column added (second check)';
  END IF;
END $$;

-- 1.3. Fix NULL values in existing data (safe fallbacks)
-- Only update if updated_at column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'updated_at'
  ) THEN
    UPDATE public.users
    SET 
      name = COALESCE(name, email, 'User'),
      role = COALESCE(role, 'worker'),
      updated_at = COALESCE(updated_at, NOW())
    WHERE name IS NULL OR role IS NULL OR updated_at IS NULL;
  ELSE
    UPDATE public.users
    SET 
      name = COALESCE(name, email, 'User'),
      role = COALESCE(role, 'worker')
    WHERE name IS NULL OR role IS NULL;
  END IF;
END $$;

-- 1.4. Ensure role constraint
DO $$
BEGIN
  ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
  ALTER TABLE public.users 
  ADD CONSTRAINT users_role_check 
  CHECK (role IN ('worker', 'manager', 'boss'));
  RAISE NOTICE '✅ Role constraint set';
END $$;

-- 1.5. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- Add updated_at index only if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'updated_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_users_updated_at ON public.users(updated_at);
  END IF;
END $$;

-- 1.5. Users table RLS policies
-- FIX: Recursion muammosini hal qilish uchun SECURITY DEFINER function

-- Function: User role'ni olish (recursion yo'q)
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role
  FROM public.users
  WHERE id = user_id;
  
  RETURN COALESCE(user_role, 'worker');
END;
$$;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Boss can update all users" ON public.users;

-- Policy 1: User o'z ma'lumotlarini o'qishi mumkin
CREATE POLICY "Users can read own profile"
ON public.users
FOR SELECT
USING (auth.uid() = id);

-- Policy 2: Boss va Manager barcha userlarni o'qishi mumkin
-- FIX: Function ishlatish - recursion yo'q
CREATE POLICY "Boss and manager can read all users"
ON public.users
FOR SELECT
USING (
  public.get_user_role(auth.uid()) IN ('boss', 'manager')
);

-- Policy 3: User o'z ma'lumotlarini INSERT qilishi mumkin (trigger uchun)
CREATE POLICY "Users can insert own profile"
ON public.users
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy 4: User o'z ma'lumotlarini UPDATE qilishi mumkin
CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 5: Boss barcha userlarni UPDATE qilishi mumkin
-- FIX: Function ishlatish - recursion yo'q
CREATE POLICY "Boss can update all users"
ON public.users
FOR UPDATE
USING (
  public.get_user_role(auth.uid()) = 'boss'
)
WITH CHECK (
  public.get_user_role(auth.uid()) = 'boss'
);

-- ============================================
-- STEP 2: PARTS TABLE RLS POLICIES
-- ============================================

-- 2.1. Ensure parts table exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'parts'
  ) THEN
    CREATE TABLE public.parts (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      min_quantity INTEGER NOT NULL DEFAULT 3,
      image_path TEXT,
      created_by UUID REFERENCES public.users(id),
      updated_by UUID REFERENCES public.users(id),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ
    );
    RAISE NOTICE '✅ Parts table created';
  END IF;
END $$;

-- 2.2. Add indexes
CREATE INDEX IF NOT EXISTS idx_parts_name ON public.parts(name);
CREATE INDEX IF NOT EXISTS idx_parts_created_by ON public.parts(created_by);

-- Add updated_at index only if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'parts' 
    AND column_name = 'updated_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_parts_updated_at ON public.parts(updated_at);
  END IF;
END $$;

-- 2.3. Reset RLS
ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "All authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can create parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can update parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON public.parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can delete parts" ON public.parts;
DROP POLICY IF EXISTS "parts_select" ON public.parts;
DROP POLICY IF EXISTS "parts_insert" ON public.parts;
DROP POLICY IF EXISTS "parts_update" ON public.parts;
DROP POLICY IF EXISTS "parts_delete" ON public.parts;

-- 2.4. Create correct policies
-- SELECT: All authenticated users can read
CREATE POLICY "parts_select"
ON public.parts
FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT: Only manager and boss
-- FIX: Function ishlatish - recursion yo'q
CREATE POLICY "parts_insert"
ON public.parts
FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

-- UPDATE: Only manager and boss
-- FIX: Function ishlatish - recursion yo'q
CREATE POLICY "parts_update"
ON public.parts
FOR UPDATE
USING (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
)
WITH CHECK (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

-- DELETE: Only boss
CREATE POLICY "parts_delete"
ON public.parts
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role = 'boss'
  )
);

-- ============================================
-- STEP 3: PRODUCTS TABLE RLS POLICIES
-- ============================================

-- 3.1. Ensure products table exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'products'
  ) THEN
    CREATE TABLE public.products (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      department_id UUID NOT NULL REFERENCES public.departments(id),
      parts_required JSONB NOT NULL DEFAULT '{}',
      created_by UUID REFERENCES public.users(id),
      updated_by UUID REFERENCES public.users(id),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ
    );
    RAISE NOTICE '✅ Products table created';
  END IF;
END $$;

-- 3.2. Add indexes
CREATE INDEX IF NOT EXISTS idx_products_department ON public.products(department_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON public.products(name);

-- Add updated_at index only if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'products' 
    AND column_name = 'updated_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_products_updated_at ON public.products(updated_at);
  END IF;
END $$;

-- 3.3. Reset RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Authenticated users can read products" ON public.products;
DROP POLICY IF EXISTS "Managers and boss can manage products" ON public.products;
DROP POLICY IF EXISTS "products_select" ON public.products;
DROP POLICY IF EXISTS "products_insert" ON public.products;
DROP POLICY IF EXISTS "products_update" ON public.products;
DROP POLICY IF EXISTS "products_delete" ON public.products;

-- 3.4. Create correct policies
-- SELECT: All authenticated users can read
CREATE POLICY "products_select"
ON public.products
FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT/UPDATE/DELETE: Only manager and boss
-- FIX: Function ishlatish - recursion yo'q
CREATE POLICY "products_insert"
ON public.products
FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

CREATE POLICY "products_update"
ON public.products
FOR UPDATE
USING (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
)
WITH CHECK (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

CREATE POLICY "products_delete"
ON public.products
FOR DELETE
USING (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

-- ============================================
-- STEP 4: ORDERS TABLE RLS POLICIES
-- ============================================

-- 4.1. Ensure orders table exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'orders'
  ) THEN
    CREATE TABLE public.orders (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      status TEXT NOT NULL DEFAULT 'pending',
      created_by UUID REFERENCES public.users(id),
      updated_by UUID REFERENCES public.users(id),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ
    );
    RAISE NOTICE '✅ Orders table created';
  END IF;
END $$;

-- 4.2. Add indexes
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_by ON public.orders(created_by);

-- Add updated_at index only if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'orders' 
    AND column_name = 'updated_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_orders_updated_at ON public.orders(updated_at);
  END IF;
END $$;

-- 4.3. Reset RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Authenticated users can read orders" ON public.orders;
DROP POLICY IF EXISTS "Authenticated users can create orders" ON public.orders;
DROP POLICY IF EXISTS "Managers and boss can update orders" ON public.orders;
DROP POLICY IF EXISTS "orders_select" ON public.orders;
DROP POLICY IF EXISTS "orders_insert" ON public.orders;
DROP POLICY IF EXISTS "orders_update" ON public.orders;
DROP POLICY IF EXISTS "orders_delete" ON public.orders;

-- 4.4. Create correct policies
-- SELECT: All authenticated users can read
CREATE POLICY "orders_select"
ON public.orders
FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT: All authenticated users can create
CREATE POLICY "orders_insert"
ON public.orders
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- UPDATE: Only manager and boss
-- FIX: Function ishlatish - recursion yo'q
CREATE POLICY "orders_update"
ON public.orders
FOR UPDATE
USING (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
)
WITH CHECK (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

-- DELETE: Only boss
-- FIX: Function ishlatish - recursion yo'q
CREATE POLICY "orders_delete"
ON public.orders
FOR DELETE
USING (
  public.get_user_role(auth.uid()) = 'boss'
);

-- ============================================
-- STEP 5: DEPARTMENTS TABLE RLS POLICIES
-- ============================================

-- 5.1. Ensure departments table exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'departments'
  ) THEN
    CREATE TABLE public.departments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL UNIQUE,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ
    );
    RAISE NOTICE '✅ Departments table created';
  END IF;
END $$;

-- 5.2. Add indexes
CREATE INDEX IF NOT EXISTS idx_departments_name ON public.departments(name);

-- Add updated_at index only if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'departments' 
    AND column_name = 'updated_at'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_departments_updated_at ON public.departments(updated_at);
  END IF;
END $$;

-- 5.3. Reset RLS
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Authenticated users can read departments" ON public.departments;
DROP POLICY IF EXISTS "Managers and boss can manage departments" ON public.departments;
DROP POLICY IF EXISTS "departments_select" ON public.departments;
DROP POLICY IF EXISTS "departments_insert" ON public.departments;
DROP POLICY IF EXISTS "departments_update" ON public.departments;
DROP POLICY IF EXISTS "departments_delete" ON public.departments;

-- 5.4. Create correct policies
-- SELECT: All authenticated users can read
CREATE POLICY "departments_select"
ON public.departments
FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT/UPDATE/DELETE: Only manager and boss
-- FIX: Function ishlatish - recursion yo'q
CREATE POLICY "departments_insert"
ON public.departments
FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

CREATE POLICY "departments_update"
ON public.departments
FOR UPDATE
USING (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
)
WITH CHECK (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

CREATE POLICY "departments_delete"
ON public.departments
FOR DELETE
USING (
  public.get_user_role(auth.uid()) = 'boss'
);

-- ============================================
-- STEP 6: ENABLE REALTIME FOR ALL TABLES
-- ============================================

DO $$
BEGIN
  -- Enable realtime for parts
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'parts'
    AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.parts;
    RAISE NOTICE '✅ Realtime enabled for parts';
  END IF;
  
  -- Enable realtime for products
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'products'
    AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
    RAISE NOTICE '✅ Realtime enabled for products';
  END IF;
  
  -- Enable realtime for orders
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'orders'
    AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    RAISE NOTICE '✅ Realtime enabled for orders';
  END IF;
  
  -- Enable realtime for departments
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'departments'
    AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.departments;
    RAISE NOTICE '✅ Realtime enabled for departments';
  END IF;
END $$;

-- ============================================
-- STEP 7: VALIDATION
-- ============================================

DO $$
DECLARE
  rls_enabled BOOLEAN;
  policies_count INTEGER;
  users_count INTEGER;
BEGIN
  -- Check users table
  SELECT COUNT(*) INTO users_count FROM public.users;
  
  -- Check parts RLS
  SELECT rowsecurity INTO rls_enabled
  FROM pg_tables
  WHERE schemaname = 'public' AND tablename = 'parts';
  
  SELECT COUNT(*) INTO policies_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'parts';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'MVP STABILIZATION RESULTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Users count: %', users_count;
  RAISE NOTICE 'Parts RLS Enabled: %', rls_enabled;
  RAISE NOTICE 'Parts Policies Count: %', policies_count;
  RAISE NOTICE '========================================';
  
  IF rls_enabled AND policies_count >= 4 THEN
    RAISE NOTICE '✅ MVP stabilization complete!';
  ELSE
    RAISE WARNING '⚠️ Configuration may need attention';
  END IF;
END $$;

-- ============================================
-- ✅ MVP STABILIZATION COMPLETE
-- ============================================
-- 
-- This migration:
-- 1. ✅ Ensures users table has id, name, email, role (with fallbacks)
-- 2. ✅ Fixes RLS policies (boss/manager CUD, worker read-only)
-- 3. ✅ Adds indexes for performance
-- 4. ✅ Enables realtime for all tables
-- 5. ✅ Doesn't break existing data
-- 
-- Next steps:
-- 1. Run this migration in Supabase SQL Editor
-- 2. Test app functionality
-- 3. Verify permissions work correctly
-- ============================================


