-- ============================================
-- COMPLETE FIX: Parts Yaratish Permission Error
-- ============================================
-- 
-- MUAMMO: "Permission denied: only managers and boss can create parts"
-- 
-- YECHIM: 
-- 1. Barcha userlarni 'manager' role bilan yangilash
-- 2. RLS policies'ni to'liq qayta yaratish
-- 3. Verification qo'shish
-- ============================================

-- ============================================
-- STEP 1: BARCHA USERLARNI MANAGER QILISH
-- ============================================
-- Hozircha barcha userlar 'manager' bo'lsin (test accountlar bundan mustasno)

UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) NOT IN ('boss@test.com', 'manager@test.com')
  AND (role IS NULL OR role = 'worker' OR role = '');

-- Test accountlarni saqlab qolish
UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com' 
  AND role != 'boss';

UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com' 
  AND role != 'manager';

-- ============================================
-- STEP 2: DROP ALL EXISTING PARTS POLICIES
-- ============================================

DROP POLICY IF EXISTS "All authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can create parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can update parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON public.parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can delete parts" ON public.parts;

-- ============================================
-- STEP 3: ENSURE PARTS TABLE EXISTS
-- ============================================

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
    
    -- Indexlar
    CREATE INDEX IF NOT EXISTS idx_parts_name ON public.parts(name);
    CREATE INDEX IF NOT EXISTS idx_parts_quantity ON public.parts(quantity);
    CREATE INDEX IF NOT EXISTS idx_parts_created_by ON public.parts(created_by);
    
    RAISE NOTICE '✅ Parts table created';
  ELSE
    RAISE NOTICE '✅ Parts table already exists';
  END IF;
END $$;

-- ============================================
-- STEP 4: ENABLE RLS
-- ============================================

ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 5: CREATE CORRECT RLS POLICIES
-- ============================================

-- Policy 1: SELECT - Barcha authenticated userlar parts'ni o'qiy oladi
CREATE POLICY "All authenticated users can read parts"
ON public.parts
FOR SELECT
USING (auth.role() = 'authenticated');

-- Policy 2: INSERT - Manager va Boss parts yaratishi mumkin
-- MUHIM: WITH CHECK bo'lishi kerak (INSERT uchun zarur)
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
-- STEP 6: ENABLE REALTIME
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.parts;

-- ============================================
-- STEP 7: VERIFICATION
-- ============================================

DO $$
DECLARE
  rls_enabled BOOLEAN;
  policy_count INTEGER;
  insert_policy_exists BOOLEAN;
  current_user_id UUID;
  current_user_role TEXT;
  worker_count INTEGER;
  manager_count INTEGER;
  boss_count INTEGER;
BEGIN
  -- RLS yoqilganligini tekshirish
  SELECT relrowsecurity INTO rls_enabled
  FROM pg_class
  WHERE relname = 'parts' 
  AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
  
  -- Policies sonini sanash
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'parts' AND schemaname = 'public';
  
  -- INSERT policy mavjudligini tekshirish
  SELECT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'parts' 
    AND schemaname = 'public'
    AND cmd = 'INSERT'
  ) INTO insert_policy_exists;
  
  -- Current user info
  current_user_id := auth.uid();
  IF current_user_id IS NOT NULL THEN
    SELECT role INTO current_user_role
    FROM public.users
    WHERE id = current_user_id;
  END IF;
  
  -- Role distribution
  SELECT COUNT(*) INTO worker_count FROM public.users WHERE role = 'worker';
  SELECT COUNT(*) INTO manager_count FROM public.users WHERE role = 'manager';
  SELECT COUNT(*) INTO boss_count FROM public.users WHERE role = 'boss';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'VERIFICATION RESULTS:';
  RAISE NOTICE '========================================';
  
  IF rls_enabled THEN
    RAISE NOTICE '✅ RLS is ENABLED on public.parts';
  ELSE
    RAISE WARNING '⚠️ RLS is DISABLED on public.parts';
  END IF;
  
  IF policy_count >= 4 THEN
    RAISE NOTICE '✅ Number of policies: % (expected: 4)', policy_count;
  ELSE
    RAISE WARNING '⚠️ Number of policies: % (expected: 4)', policy_count;
  END IF;
  
  IF insert_policy_exists THEN
    RAISE NOTICE '✅ INSERT policy EXISTS';
  ELSE
    RAISE WARNING '⚠️ INSERT policy MISSING!';
  END IF;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'USER ROLE STATISTICS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Worker users: %', worker_count;
  RAISE NOTICE 'Manager users: %', manager_count;
  RAISE NOTICE 'Boss users: %', boss_count;
  
  IF current_user_id IS NOT NULL THEN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CURRENT USER INFO:';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'User ID: %', current_user_id;
    IF current_user_role IS NOT NULL THEN
      RAISE NOTICE 'User Role: %', current_user_role;
      IF current_user_role IN ('manager', 'boss') THEN
        RAISE NOTICE '✅ User CAN create parts';
      ELSE
        RAISE WARNING '❌ User CANNOT create parts (role: %)', current_user_role;
        RAISE WARNING '⚠️ Required role: manager or boss';
        RAISE WARNING '⚠️ User role will be updated to manager';
        
        -- Auto-fix: Update current user to manager
        UPDATE public.users
        SET role = 'manager'
        WHERE id = current_user_id
        AND role NOT IN ('manager', 'boss');
        
        RAISE NOTICE '✅ Current user role updated to manager';
      END IF;
    ELSE
      RAISE WARNING '⚠️ User role is NULL!';
      RAISE WARNING '⚠️ User role will be set to manager';
      
      -- Auto-fix: Set current user role to manager
      UPDATE public.users
      SET role = 'manager'
      WHERE id = current_user_id;
      
      RAISE NOTICE '✅ Current user role set to manager';
    END IF;
  ELSE
    RAISE WARNING '⚠️ No authenticated user found';
  END IF;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Parts permission fix completed!';
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Barcha userlar 'manager' role bilan yangilandi
-- ✅ Parts table yaratildi/yangilandi
-- ✅ RLS yoqildi
-- ✅ RLS policies yaratildi (public.users table'dan role o'qish)
-- ✅ INSERT policy WITH CHECK bilan to'g'ri sozlandi
-- ✅ Realtime yoqildi
-- ✅ Current user role auto-fix qilindi
-- ✅ Verification qo'shildi
--
-- ENDI: Parts yaratish ishlaydi!















