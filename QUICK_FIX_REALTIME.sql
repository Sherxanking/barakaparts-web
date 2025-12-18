-- ============================================
-- QUICK FIX: Enable Realtime for Products and Orders
-- ============================================
-- Copy-paste this SQL to Supabase SQL Editor
-- ============================================

-- Enable realtime for products
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE products;
    RAISE NOTICE '✅ Added products table to realtime';
  ELSE
    RAISE NOTICE 'ℹ️ Products table already in realtime';
  END IF;
END $$;

-- Enable realtime for orders
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE orders;
    RAISE NOTICE '✅ Added orders table to realtime';
  ELSE
    RAISE NOTICE 'ℹ️ Orders table already in realtime';
  END IF;
END $$;

-- Verify
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename IN ('products', 'orders');







