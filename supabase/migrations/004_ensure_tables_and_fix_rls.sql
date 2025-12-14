-- ============================================
-- Migration 004: Ensure All Tables Exist + Fix RLS Policies
-- ============================================
-- 
-- WHY: This migration ensures all required tables exist before applying RLS policies.
-- Prevents "relation does not exist" errors when running migrations.
-- 
-- This is a safe migration that:
-- 1. Creates tables if they don't exist (with proper structure)
-- 2. Adds missing columns if tables exist but are incomplete
-- 3. Applies RLS policies safely
-- 4. Creates indexes for performance
-- ============================================

-- ============================================
-- 1. DEPARTMENTS TABLE
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'departments') THEN
    CREATE TABLE departments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL UNIQUE,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    CREATE INDEX idx_departments_name ON departments(name);
    
    -- Insert default departments
    INSERT INTO departments (name) VALUES
      ('Assembly'),
      ('Packaging'),
      ('Quality Control')
    ON CONFLICT (name) DO NOTHING;
    
    RAISE NOTICE 'Created departments table';
  ELSE
    RAISE NOTICE 'Departments table already exists';
  END IF;
END $$;

-- Enable RLS
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can read departments" ON departments;
DROP POLICY IF EXISTS "Managers and boss can create departments" ON departments;
DROP POLICY IF EXISTS "Managers and boss can update departments" ON departments;
DROP POLICY IF EXISTS "Boss can delete departments" ON departments;

-- Create policies
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
-- 2. USERS TABLE
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
    CREATE TABLE users (
      id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      email TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      phone TEXT,
      role TEXT NOT NULL CHECK (role IN ('boss', 'manager', 'worker', 'supplier')) DEFAULT 'worker',
      department_id UUID REFERENCES departments(id),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    CREATE INDEX idx_users_role ON users(role);
    CREATE INDEX idx_users_department ON users(department_id);
    CREATE INDEX idx_users_email ON users(email);
    
    RAISE NOTICE 'Created users table';
  ELSE
    -- Add missing columns if table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'department_id') THEN
      ALTER TABLE users ADD COLUMN department_id UUID REFERENCES departments(id);
      CREATE INDEX IF NOT EXISTS idx_users_department ON users(department_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'phone') THEN
      ALTER TABLE users ADD COLUMN phone TEXT;
    END IF;
    
    RAISE NOTICE 'Users table already exists, checked for missing columns';
  END IF;
END $$;

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can read own data" ON users;
DROP POLICY IF EXISTS "Boss can read all users" ON users;
DROP POLICY IF EXISTS "Manager can read department users" ON users;
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;
DROP POLICY IF EXISTS "Boss can update users" ON users;

-- Create policies
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
-- 3. PARTS TABLE
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'parts') THEN
    CREATE TABLE parts (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      min_quantity INTEGER NOT NULL DEFAULT 3,
      image_path TEXT,
      created_by UUID REFERENCES users(id),
      updated_by UUID REFERENCES users(id),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ
    );
    
    CREATE INDEX idx_parts_name ON parts(name);
    CREATE INDEX idx_parts_quantity ON parts(quantity);
    CREATE INDEX idx_parts_created_by ON parts(created_by);
    
    RAISE NOTICE 'Created parts table';
  ELSE
    -- Add missing columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'parts' AND column_name = 'min_quantity') THEN
      ALTER TABLE parts ADD COLUMN min_quantity INTEGER NOT NULL DEFAULT 3;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'parts' AND column_name = 'image_path') THEN
      ALTER TABLE parts ADD COLUMN image_path TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'parts' AND column_name = 'created_by') THEN
      ALTER TABLE parts ADD COLUMN created_by UUID REFERENCES users(id);
      CREATE INDEX IF NOT EXISTS idx_parts_created_by ON parts(created_by);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'parts' AND column_name = 'updated_by') THEN
      ALTER TABLE parts ADD COLUMN updated_by UUID REFERENCES users(id);
    END IF;
    
    RAISE NOTICE 'Parts table already exists, checked for missing columns';
  END IF;
END $$;

-- Enable RLS
ALTER TABLE parts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can read parts" ON parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON parts;

-- Create policies
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
-- 4. PRODUCTS TABLE
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products') THEN
    CREATE TABLE products (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      department_id UUID NOT NULL REFERENCES departments(id),
      parts_required JSONB NOT NULL DEFAULT '{}',
      created_by UUID REFERENCES users(id),
      updated_by UUID REFERENCES users(id),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ
    );
    
    CREATE INDEX idx_products_department ON products(department_id);
    CREATE INDEX idx_products_name ON products(name);
    CREATE INDEX idx_products_created_by ON products(created_by);
    
    RAISE NOTICE 'Created products table';
  ELSE
    -- Add missing columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'created_by') THEN
      ALTER TABLE products ADD COLUMN created_by UUID REFERENCES users(id);
      CREATE INDEX IF NOT EXISTS idx_products_created_by ON products(created_by);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'updated_by') THEN
      ALTER TABLE products ADD COLUMN updated_by UUID REFERENCES users(id);
    END IF;
    
    RAISE NOTICE 'Products table already exists, checked for missing columns';
  END IF;
END $$;

-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies (including any variations)
DROP POLICY IF EXISTS "Authenticated users can read products" ON products;
DROP POLICY IF EXISTS "Managers and boss can manage products" ON products;
DROP POLICY IF EXISTS "Managers and boss can create products" ON products;
DROP POLICY IF EXISTS "Managers and boss can update products" ON products;
DROP POLICY IF EXISTS "Boss can delete products" ON products;

-- Create policies
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
-- 5. ORDERS TABLE
-- ============================================
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
    CREATE INDEX idx_orders_product ON orders(product_id);
    CREATE INDEX idx_orders_created_by ON orders(created_by);
    
    RAISE NOTICE 'Created orders table';
  ELSE
    -- Add missing columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'created_by') THEN
      ALTER TABLE orders ADD COLUMN created_by UUID REFERENCES users(id);
      CREATE INDEX IF NOT EXISTS idx_orders_created_by ON orders(created_by);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'approved_by') THEN
      ALTER TABLE orders ADD COLUMN approved_by UUID REFERENCES users(id);
    END IF;
    
    RAISE NOTICE 'Orders table already exists, checked for missing columns';
  END IF;
END $$;

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can read orders" ON orders;
DROP POLICY IF EXISTS "Authenticated users can create orders" ON orders;
DROP POLICY IF EXISTS "Managers and boss can update orders" ON orders;
DROP POLICY IF EXISTS "Boss can delete orders" ON orders;

-- Create policies
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
-- 6. TRIGGER: Auto-create user profile on signup
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, department_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'worker')::text,
    (NEW.raw_user_meta_data->>'department_id')::uuid
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- SUMMARY
-- ============================================
-- This migration:
-- ✅ Creates all tables if they don't exist
-- ✅ Adds missing columns to existing tables
-- ✅ Applies RLS policies safely
-- ✅ Creates necessary indexes
-- ✅ Sets up trigger for auto user creation
-- 
-- Safe to run multiple times - uses IF NOT EXISTS checks
-- ============================================

