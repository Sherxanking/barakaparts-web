-- ============================================
-- Migration 1008: RLS + Role Consistency Fix
-- ============================================
--
-- GOAL:
-- 1) Ensure public.users row always exists for auth.users
-- 2) Ensure public.users.role is never NULL/invalid
-- 3) Use public.users.role in RLS (single source of truth)
--
-- NOTE: This migration does NOT touch UI or app code.
-- ============================================

-- ============================================
-- STEP 1: Backfill missing public.users rows
-- ============================================
INSERT INTO public.users (id, email, name, role, created_at, updated_at)
SELECT
  au.id,
  au.email,
  COALESCE(
    au.raw_user_meta_data->>'name',
    au.raw_user_meta_data->>'full_name',
    split_part(au.email, '@', 1),
    'User'
  ) AS name,
  CASE
    WHEN LOWER(au.email) = 'boss@test.com' THEN 'boss'
    WHEN LOWER(au.email) = 'manager@test.com' THEN 'manager'
    WHEN (au.raw_user_meta_data->>'role') IN ('worker', 'manager', 'boss', 'supplier') THEN au.raw_user_meta_data->>'role'
    ELSE 'worker'
  END AS role,
  COALESCE(au.created_at, NOW()) AS created_at,
  NOW() AS updated_at
FROM auth.users au
LEFT JOIN public.users pu ON pu.id = au.id
WHERE pu.id IS NULL;

-- ============================================
-- STEP 2: Normalize role in public.users (never NULL/invalid)
-- ============================================
UPDATE public.users
SET role = CASE
  WHEN LOWER(email) = 'boss@test.com' THEN 'boss'
  WHEN LOWER(email) = 'manager@test.com' THEN 'manager'
  WHEN role IN ('worker', 'manager', 'boss', 'supplier') THEN role
  ELSE 'worker'
END
WHERE role IS NULL
   OR role = ''
   OR role NOT IN ('worker', 'manager', 'boss', 'supplier');

-- Ensure NOT NULL + default if possible
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'role'
      AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE public.users
    ALTER COLUMN role SET NOT NULL;
  END IF;

  ALTER TABLE public.users
  ALTER COLUMN role SET DEFAULT 'worker';
END $$;

-- ============================================
-- STEP 3: Fix trigger to always create public.users row + role
-- ============================================
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
  metadata_role TEXT;
BEGIN
  user_email := COALESCE(NEW.email, '');
  metadata_role := NEW.raw_user_meta_data->>'role';

  IF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF metadata_role IN ('worker', 'manager', 'boss', 'supplier') THEN
    user_role := metadata_role;
  ELSE
    user_role := 'worker';
  END IF;

  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );

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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 4: RLS policy updates to use public.users role
-- ============================================

-- USERS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Boss can read all users" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Manager can read department users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Boss can update users" ON public.users;

CREATE POLICY "Users can read own data" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Boss and manager can read all users" ON public.users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('boss', 'manager')
    )
  );

-- Create department-scoped policy only if department_id exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'department_id'
  ) THEN
    EXECUTE $POLICY$
      CREATE POLICY "Manager can read department users" ON public.users
        FOR SELECT USING (
          EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
              AND u.role = 'manager'
              AND u.department_id IS NOT NULL
              AND u.department_id = public.users.department_id
          )
        );
    $POLICY$;
  END IF;
END $$;

CREATE POLICY "Users can insert own data" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Boss can update users" ON public.users
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role = 'boss'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role = 'boss'
    )
  );

-- DEPARTMENTS
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can read departments" ON public.departments;
DROP POLICY IF EXISTS "Managers and boss can create departments" ON public.departments;
DROP POLICY IF EXISTS "Managers and boss can update departments" ON public.departments;
DROP POLICY IF EXISTS "Boss can delete departments" ON public.departments;

CREATE POLICY "Authenticated users can read departments" ON public.departments
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can create departments" ON public.departments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('manager', 'boss')
    )
  );

CREATE POLICY "Managers and boss can update departments" ON public.departments
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('manager', 'boss')
    )
  );

CREATE POLICY "Boss can delete departments" ON public.departments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role = 'boss'
    )
  );

-- PARTS
ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON public.parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON public.parts;

CREATE POLICY "Authenticated users can read parts" ON public.parts
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authorized users can create parts" ON public.parts
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('worker', 'manager', 'boss', 'supplier')
    )
  );

CREATE POLICY "Authorized users can update parts" ON public.parts
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('manager', 'boss', 'supplier')
    )
  );

CREATE POLICY "Boss can delete parts" ON public.parts
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role = 'boss'
    )
  );

-- PRODUCTS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can read products" ON public.products;
DROP POLICY IF EXISTS "Managers and boss can create products" ON public.products;
DROP POLICY IF EXISTS "Managers and boss can update products" ON public.products;
DROP POLICY IF EXISTS "Boss can delete products" ON public.products;

CREATE POLICY "Authenticated users can read products" ON public.products
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can create products" ON public.products
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('manager', 'boss')
    )
  );

CREATE POLICY "Managers and boss can update products" ON public.products
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('manager', 'boss')
    )
  );

CREATE POLICY "Boss can delete products" ON public.products
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role = 'boss'
    )
  );

-- ORDERS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can read orders" ON public.orders;
DROP POLICY IF EXISTS "Authenticated users can create orders" ON public.orders;
DROP POLICY IF EXISTS "Managers and boss can update orders" ON public.orders;
DROP POLICY IF EXISTS "Boss can delete orders" ON public.orders;
DROP POLICY IF EXISTS "orders_delete" ON public.orders;

CREATE POLICY "Authenticated users can read orders" ON public.orders
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create orders" ON public.orders
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can update orders" ON public.orders
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN ('manager', 'boss')
    )
  );

CREATE POLICY "Boss can delete orders" ON public.orders
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role = 'boss'
    )
  );

-- ============================================
-- ✅ DONE
-- ============================================
