-- ============================================
-- Enable Realtime for Products and Orders Tables
-- ============================================
-- WHY: Products and Orders must sync in real-time across all devices
-- This migration enables realtime subscriptions for products and orders tables
-- ============================================

-- Enable realtime publication for products table
-- FIX: IF NOT EXISTS is not supported in ALTER PUBLICATION, use DO block instead
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE products;
    RAISE NOTICE 'Added products table to supabase_realtime publication';
  ELSE
    RAISE NOTICE 'Products table already in supabase_realtime publication';
  END IF;
END $$;

-- Enable realtime publication for orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE orders;
    RAISE NOTICE 'Added orders table to supabase_realtime publication';
  ELSE
    RAISE NOTICE 'Orders table already in supabase_realtime publication';
  END IF;
END $$;

-- Verify RLS policies exist for SELECT (all authenticated users can read)
DO $$
BEGIN
  -- Products SELECT policy
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'products' 
    AND policyname LIKE '%read%' OR policyname LIKE '%select%'
  ) THEN
    CREATE POLICY "Authenticated users can read products" ON products
      FOR SELECT USING (auth.role() = 'authenticated');
    RAISE NOTICE 'Created SELECT policy for products table';
  ELSE
    RAISE NOTICE 'SELECT policy for products table already exists';
  END IF;

  -- Orders SELECT policy
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND (policyname LIKE '%read%' OR policyname LIKE '%select%')
  ) THEN
    CREATE POLICY "Authenticated users can read orders" ON orders
      FOR SELECT USING (auth.role() = 'authenticated');
    RAISE NOTICE 'Created SELECT policy for orders table';
  ELSE
    RAISE NOTICE 'SELECT policy for orders table already exists';
  END IF;
END $$;

