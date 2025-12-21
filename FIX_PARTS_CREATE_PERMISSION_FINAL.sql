-- ============================================
-- FIX PARTS CREATE PERMISSION - Final Fix
-- ============================================
-- 
-- MUAMMO: Google login bilan manager roli bilan kirgan user parts yarata olmayapti
-- SABAB: User'ning role'i hali ham 'worker' yoki RLS policy to'g'ri ishlamayapti
-- YECHIM: User role'ni tekshirish va RLS policy'ni yangilash
-- ============================================

-- ============================================
-- STEP 1: MAVJUD USERLARNI TEKSHIRISH
-- ============================================

-- Barcha userlarni role bilan ko'rsatish
SELECT 
  au.id,
  au.email,
  pu.role,
  ai.provider,
  CASE 
    WHEN pu.role = 'manager' THEN '✅ Manager'
    WHEN pu.role = 'worker' THEN '❌ Worker (needs update)'
    WHEN pu.role = 'boss' THEN '✅ Boss'
    ELSE '⚠️ Unknown'
  END as status
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
LEFT JOIN auth.identities ai ON au.id = ai.user_id
ORDER BY pu.role, au.email;

-- ============================================
-- STEP 2: GOOGLE USERLARNI MANAGER QILISH
-- ============================================

-- Barcha Google userlarni 'manager' roliga yangilash
UPDATE public.users
SET role = 'manager'
WHERE id IN (
  SELECT au.id
  FROM auth.users au
  INNER JOIN auth.identities ai ON au.id = ai.user_id
  WHERE ai.provider = 'google'
  AND au.email NOT IN ('boss@test.com', 'manager@test.com')
)
AND role != 'manager'
AND role != 'boss';

-- ============================================
-- STEP 3: PARTS TABLE RLS POLICIES'NI YANGILASH
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "All authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can create parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can update parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON public.parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can delete parts" ON public.parts;

-- Policy 1: SELECT - Barcha authenticated userlar parts'ni o'qiy oladi
CREATE POLICY "All authenticated users can read parts"
ON public.parts
FOR SELECT
USING (auth.role() = 'authenticated');

-- Policy 2: INSERT - Manager va Boss parts yaratishi mumkin
-- FIX: WITH CHECK bo'lishi kerak (INSERT uchun zarur)
CREATE POLICY "Managers and boss can create parts"
ON public.parts
FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role IN ('manager', 'boss')
  )
);

-- Policy 3: UPDATE - Manager va Boss parts yangilashi mumkin
CREATE POLICY "Managers and boss can update parts"
ON public.parts
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role IN ('manager', 'boss')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role IN ('manager', 'boss')
  )
);

-- Policy 4: DELETE - Faqat Boss parts o'chirishi mumkin
CREATE POLICY "Boss can delete parts"
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
-- STEP 4: RLS ENABLED EKANLIGINI TEKSHIRISH
-- ============================================

-- RLS enabled ekanligini tekshirish
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'parts';

-- ============================================
-- STEP 5: CURRENT USER ROLE'NI TEKSHIRISH
-- ============================================

-- Joriy user'ning role'ini tekshirish (test uchun)
-- NOTE: Bu query'ni app'dan bajarish kerak
SELECT 
  auth.uid() as current_user_id,
  pu.role as current_user_role,
  CASE 
    WHEN pu.role IN ('manager', 'boss') THEN '✅ Can create parts'
    ELSE '❌ Cannot create parts'
  END as permission_status
FROM public.users pu
WHERE pu.id = auth.uid();

-- ============================================
-- STEP 6: TEKSHIRISH VA STATISTIKA
-- ============================================

DO $$
DECLARE
  manager_count INTEGER;
  worker_count INTEGER;
  boss_count INTEGER;
  parts_policies_count INTEGER;
BEGIN
  -- Manager roli bilan userlarni sanash
  SELECT COUNT(*) INTO manager_count
  FROM public.users
  WHERE role = 'manager';
  
  -- Worker roli bilan userlarni sanash
  SELECT COUNT(*) INTO worker_count
  FROM public.users
  WHERE role = 'worker';
  
  -- Boss roli bilan userlarni sanash
  SELECT COUNT(*) INTO boss_count
  FROM public.users
  WHERE role = 'boss';
  
  -- Parts table RLS policies'ni sanash
  SELECT COUNT(*) INTO parts_policies_count
  FROM pg_policies
  WHERE schemaname = 'public'
  AND tablename = 'parts';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PARTS CREATE PERMISSION FIX RESULTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Manager users: %', manager_count;
  RAISE NOTICE 'Worker users: %', worker_count;
  RAISE NOTICE 'Boss users: %', boss_count;
  RAISE NOTICE 'Parts RLS policies: %', parts_policies_count;
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Google users updated to MANAGER role';
  RAISE NOTICE '✅ Parts RLS policies recreated';
  RAISE NOTICE '✅ Managers and boss can now create parts';
  RAISE NOTICE '========================================';
END $$;

-- ============================================
-- ✅ FIX COMPLETE
-- ============================================
-- Endi:
-- 1. Google userlar 'manager' roli bilan yangilandi
-- 2. Parts RLS policies to'g'ri sozlandi
-- 3. Manager va Boss parts yaratishi mumkin
-- ============================================















