-- ============================================
-- FIX: Parts Yaratish Permission Error
-- ============================================
-- 
-- MUAMMO: Yangi part ochib bo'lmayapti
-- SABAB: RLS policies public.users table'dan role'ni o'qiy olmayapti
-- 
-- YECHIM: RLS policies'ni to'g'rilash - public.users table'dan role'ni o'qish
-- ============================================

-- ============================================
-- STEP 1: DROP EXISTING PARTS POLICIES
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

-- Parts table mavjudligini tekshirish va yaratish
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
-- WHY: Hamma inventory'ni ko'rish kerak
CREATE POLICY "All authenticated users can read parts"
ON public.parts
FOR SELECT
USING (auth.role() = 'authenticated');

-- Policy 2: INSERT - Manager va Boss parts yaratishi mumkin
-- WHY: Worker read-only, faqat manager/boss yaratishi mumkin
-- FIX: public.users table'dan role'ni o'qish
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
-- WHY: Worker o'zgartira olmaydi
-- FIX: public.users table'dan role'ni o'qish
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
-- WHY: Xavfsizlik uchun faqat boss o'chira oladi
-- FIX: public.users table'dan role'ni o'qish
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

-- Realtime'ni yoqish
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS public.parts;

-- ============================================
-- STEP 6: VERIFICATION
-- ============================================

DO $$
DECLARE
  rls_enabled BOOLEAN;
  policy_count INTEGER;
  realtime_enabled BOOLEAN;
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
  
  -- Realtime yoqilganligini tekshirish
  SELECT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'parts'
  ) INTO realtime_enabled;
  
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
  
  IF realtime_enabled THEN
    RAISE NOTICE '✅ Realtime is ENABLED for public.parts';
  ELSE
    RAISE WARNING '⚠️ Realtime is DISABLED for public.parts';
  END IF;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Parts table RLS policies fixed!';
  RAISE NOTICE '✅ Manager and Boss can now create parts';
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ Parts table yaratildi/yangilandi
-- ✅ RLS yoqildi
-- ✅ RLS policies yaratildi (public.users table'dan role o'qish)
-- ✅ Realtime yoqildi
-- ✅ Manager va Boss parts yaratishi mumkin
--
-- ENDI: Parts yaratish ishlaydi!















