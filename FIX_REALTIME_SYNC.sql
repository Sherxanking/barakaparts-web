-- ============================================
-- FIX REALTIME SYNC - Barcha jadvallar uchun
-- ============================================
-- 
-- Bu SQL barcha jadvallar uchun realtime'ni yoqadi
-- Chrome va telefonda ma'lumotlar bir xil bo'lishi uchun
-- 
-- ============================================

-- Barcha jadvallar uchun realtime yoqish
DO $$
BEGIN
  -- Parts
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'parts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.parts;
    RAISE NOTICE '✅ Parts realtime yoqildi';
  ELSE
    RAISE NOTICE '✅ Parts realtime allaqachon yoqilgan';
  END IF;
  
  -- Products
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
    RAISE NOTICE '✅ Products realtime yoqildi';
  ELSE
    RAISE NOTICE '✅ Products realtime allaqachon yoqilgan';
  END IF;
  
  -- Orders
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    RAISE NOTICE '✅ Orders realtime yoqildi';
  ELSE
    RAISE NOTICE '✅ Orders realtime allaqachon yoqilgan';
  END IF;
  
  -- Departments
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'departments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.departments;
    RAISE NOTICE '✅ Departments realtime yoqildi';
  ELSE
    RAISE NOTICE '✅ Departments realtime allaqachon yoqilgan';
  END IF;
END $$;

-- Tekshirish
SELECT tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
AND tablename IN ('parts', 'products', 'orders', 'departments')
ORDER BY tablename;
































