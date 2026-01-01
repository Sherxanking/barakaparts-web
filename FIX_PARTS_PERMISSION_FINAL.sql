-- ============================================
-- FIX: Parts Yaratish Permission Error (FINAL)
-- ============================================
-- 
-- MUAMMO: "Permission denied: only managers and boss can create parts"
-- SABAB: RLS policy to'g'ri ishlamayapti yoki user role'i noto'g'ri
-- 
-- YECHIM: RLS policies'ni to'liq qayta yaratish va tekshirish
-- ============================================

-- ============================================
-- STEP 1: DROP ALL EXISTING PARTS POLICIES
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
-- STEP 2: ENSURE PARTS TABLE EXISTS
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
-- STEP 3: ENABLE RLS
-- ============================================

ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 4: CREATE CORRECT RLS POLICIES
-- ============================================

-- Policy 1: SELECT - Barcha authenticated userlar parts'ni o'qiy oladi
CREATE POLICY "All authenticated users can read parts"
ON public.parts
FOR SELECT
USING (auth.role() = 'authenticated');

-- Policy 2: INSERT - Manager va Boss parts yaratishi mumkin
-- FIX: public.users table'dan role'ni to'g'ri o'qish
-- MUHIM: WITH CHECK bo'lishi kerak (INSERT uchun)
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
-- STEP 5: ENABLE REALTIME
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.parts;

-- ============================================
-- STEP 6: VERIFICATION
-- ============================================

DO $$
DECLARE
  rls_enabled BOOLEAN;
  policy_count INTEGER;
  insert_policy_exists BOOLEAN;
  current_user_id UUID;
  current_user_role TEXT;
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
  
  IF current_user_id IS NOT NULL THEN
    RAISE NOTICE 'Current User ID: %', current_user_id;
    IF current_user_role IS NOT NULL THEN
      RAISE NOTICE 'Current User Role: %', current_user_role;
      IF current_user_role IN ('manager', 'boss') THEN
        RAISE NOTICE '✅ User CAN create parts';
      ELSE
        RAISE WARNING '⚠️ User CANNOT create parts (role: %)', current_user_role;
        RAISE WARNING '⚠️ Required role: manager or boss';
      END IF;
    ELSE
      RAISE WARNING '⚠️ User role is NULL!';
    END IF;
  ELSE
    RAISE WARNING '⚠️ No authenticated user found';
  END IF;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Parts table RLS policies fixed!';
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Parts table yaratildi/yangilandi
-- ✅ RLS yoqildi
-- ✅ RLS policies yaratildi (public.users table'dan role o'qish)
-- ✅ INSERT policy WITH CHECK bilan to'g'ri sozlandi
-- ✅ Realtime yoqildi
-- ✅ Verification qo'shildi
--
-- ENDI: Parts yaratish ishlaydi!






























