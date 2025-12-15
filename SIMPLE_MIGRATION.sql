-- ============================================
-- SIMPLE MIGRATION - SODDA YECHIM
-- ============================================
-- 
-- Faqat authenticated userlar uchun ochiq
-- RLS minimal darajada
-- 
-- ============================================

-- ============================================
-- PARTS TABLE - SODDA RLS
-- ============================================
ALTER TABLE public.parts DISABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'parts'
  ) LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.parts';
  END LOOP;
END $$;

ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read parts"
ON public.parts
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Authenticated users can insert parts"
ON public.parts
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Authenticated users can update parts"
ON public.parts
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Authenticated users can delete parts"
ON public.parts
FOR DELETE
TO authenticated
USING (true);

-- ============================================
-- PRODUCTS TABLE - SODDA RLS
-- ============================================
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'products'
  ) LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.products';
  END LOOP;
END $$;

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read products"
ON public.products
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Authenticated users can insert products"
ON public.products
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Authenticated users can update products"
ON public.products
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Authenticated users can delete products"
ON public.products
FOR DELETE
TO authenticated
USING (true);

-- ============================================
-- ORDERS TABLE - SODDA RLS
-- ============================================
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders'
  ) LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.orders';
  END LOOP;
END $$;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read orders"
ON public.orders
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Authenticated users can insert orders"
ON public.orders
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Authenticated users can update orders"
ON public.orders
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Authenticated users can delete orders"
ON public.orders
FOR DELETE
TO authenticated
USING (true);

-- ============================================
-- DEPARTMENTS TABLE - SODDA RLS
-- ============================================
ALTER TABLE public.departments DISABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'departments'
  ) LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.departments';
  END LOOP;
END $$;

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read departments"
ON public.departments
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Authenticated users can insert departments"
ON public.departments
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Authenticated users can update departments"
ON public.departments
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Authenticated users can delete departments"
ON public.departments
FOR DELETE
TO authenticated
USING (true);

-- ============================================
-- REALTIME YOQISH
-- ============================================
-- Xatolik bo'lmasligi uchun tekshiramiz
DO $$
BEGIN
  -- Parts
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'parts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.parts;
  END IF;
  
  -- Products
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
  END IF;
  
  -- Orders
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
  
  -- Departments
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'departments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.departments;
  END IF;
END $$;

