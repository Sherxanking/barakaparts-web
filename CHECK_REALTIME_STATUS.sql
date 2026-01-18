-- ============================================
-- Supabase Realtime Status Tekshirish
-- ============================================
-- Bu SQL query Supabase'da qaysi jadvallar realtime yoqilganini ko'rsatadi
-- ============================================

-- 1. Barcha realtime yoqilgan jadvallarni ko'rish
SELECT 
    tablename,
    schemaname,
    pubname
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;

-- 2. Parts, Products, Orders jadvallarini alohida tekshirish
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND tablename = 'parts'
        ) THEN '✅ Parts realtime YOQILGAN'
        ELSE '❌ Parts realtime YOQILMAGAN'
    END AS parts_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND tablename = 'products'
        ) THEN '✅ Products realtime YOQILGAN'
        ELSE '❌ Products realtime YOQILMAGAN'
    END AS products_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND tablename = 'orders'
        ) THEN '✅ Orders realtime YOQILGAN'
        ELSE '❌ Orders realtime YOQILMAGAN'
    END AS orders_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND tablename = 'departments'
        ) THEN '✅ Departments realtime YOQILGAN'
        ELSE '❌ Departments realtime YOQILMAGAN'
    END AS departments_status;

-- 3. Agar yoqilmagan bo'lsa, yoqish uchun SQL
-- (Faqat kerak bo'lsa ishlatish uchun)
/*
-- Parts uchun
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'parts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE parts;
    RAISE NOTICE '✅ Parts realtime yoqildi';
  ELSE
    RAISE NOTICE 'ℹ️ Parts realtime allaqachon yoqilgan';
  END IF;
END $$;

-- Products uchun
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE products;
    RAISE NOTICE '✅ Products realtime yoqildi';
  ELSE
    RAISE NOTICE 'ℹ️ Products realtime allaqachon yoqilgan';
  END IF;
END $$;

-- Orders uchun
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE orders;
    RAISE NOTICE '✅ Orders realtime yoqildi';
  ELSE
    RAISE NOTICE 'ℹ️ Orders realtime allaqachon yoqilgan';
  END IF;
END $$;
*/
































