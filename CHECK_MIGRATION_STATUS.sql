-- ============================================
-- Migration Status Tekshirish
-- ============================================
-- Bu SQL'ni Supabase SQL Editor'da bajarib, migration holatini tekshiring
-- ============================================

-- 1. RLS yoqilganligini tekshirish
SELECT 
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity THEN '✅ RLS YOQILGAN'
        ELSE '❌ RLS OCHIQ'
    END as status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'parts', 'products', 'orders', 'departments')
ORDER BY tablename;

-- 2. Har bir jadvaldagi policies sonini tekshirish
SELECT 
    tablename,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) >= 3 THEN '✅ YETARLI'
        ELSE '⚠️ KAM'
    END as status
FROM pg_policies 
WHERE schemaname = 'public'
AND tablename IN ('users', 'parts', 'products', 'orders', 'departments')
GROUP BY tablename
ORDER BY tablename;

-- 3. Users jadvali strukturasini tekshirish
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'users'
ORDER BY ordinal_position;

-- 4. Realtime yoqilganligini tekshirish
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
            AND schemaname = 'public' 
            AND tablename = t.tablename
        ) THEN '✅ REALTIME YOQILGAN'
        ELSE '❌ REALTIME OCHIQ'
    END as realtime_status
FROM pg_tables t
WHERE schemaname = 'public'
AND tablename IN ('users', 'parts', 'products', 'orders', 'departments')
ORDER BY tablename;

-- 5. Indexes mavjudligini tekshirish
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('users', 'parts', 'products', 'orders', 'departments')
ORDER BY tablename, indexname;

















