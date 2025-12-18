-- ============================================
-- Migration 020: Fix Parts Permissions - Complete Fix
-- ============================================
-- 
-- MUAMMO: "Permission denied: Only managers and boss can create parts"
-- SABAB: RLS policies yoki role sync muammosi
-- YECHIM: To'liq RLS reset va to'g'ri policies yaratish
-- ============================================

-- ============================================
-- STEP 1: DATABASE ROLE VERIFICATION
-- ============================================

-- 1.1. Users table structure tekshirish
DO $$
BEGIN
  -- Role column mavjudligini tekshirish
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'role'
  ) THEN
    ALTER TABLE public.users ADD COLUMN role TEXT NOT NULL DEFAULT 'worker';
    RAISE NOTICE '✅ Role column added to users table';
  ELSE
    RAISE NOTICE '✅ Role column already exists';
  END IF;
END $$;

-- 1.2. Role validatsiyasi va cleanup
UPDATE public.users
SET role = 'worker'
WHERE role IS NULL 
   OR role = ''
   OR role NOT IN ('worker', 'manager', 'boss');

-- 1.3. Role constraint qo'shish (agar yo'q bo'lsa)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_role_check'
  ) THEN
    ALTER TABLE public.users 
    ADD CONSTRAINT users_role_check 
    CHECK (role IN ('worker', 'manager', 'boss'));
    RAISE NOTICE '✅ Role constraint added';
  ELSE
    RAISE NOTICE '✅ Role constraint already exists';
  END IF;
END $$;

-- ============================================
-- STEP 2: AUTH UID vs USERS.ID SYNC
-- ============================================

-- 2.1. Missing users'ni yaratish (auth.users dan public.users ga)
INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  au.id,
  COALESCE(
    au.raw_user_meta_data->>'name',
    au.email,
    'User'
  ) as name,
  au.email,
  CASE 
    WHEN LOWER(COALESCE(au.email, '')) = 'manager@test.com' THEN 'manager'
    WHEN LOWER(COALESCE(au.email, '')) = 'boss@test.com' THEN 'boss'
    WHEN EXISTS (
      SELECT 1 FROM auth.identities ai 
      WHERE ai.user_id = au.id AND ai.provider = 'google'
    ) THEN 'manager'
    ELSE 'worker'
  END as role,
  COALESCE(au.created_at, NOW()) as created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- STEP 3: FULL RLS RESET FOR parts TABLE
-- ============================================

-- 3.1. Parts table mavjudligini tekshirish va yaratish
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

-- 3.2. RLS disable va re-enable
ALTER TABLE public.parts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;

-- 3.3. Barcha eski policies'ni o'chirish
DROP POLICY IF EXISTS "All authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Authenticated users can read parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can create parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can create parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can update parts" ON public.parts;
DROP POLICY IF EXISTS "Authorized users can update parts" ON public.parts;
DROP POLICY IF EXISTS "Boss can delete parts" ON public.parts;
DROP POLICY IF EXISTS "Managers and boss can delete parts" ON public.parts;
DROP POLICY IF EXISTS "parts_select" ON public.parts;
DROP POLICY IF EXISTS "parts_insert" ON public.parts;
DROP POLICY IF EXISTS "parts_update" ON public.parts;
DROP POLICY IF EXISTS "parts_delete" ON public.parts;

-- ============================================
-- STEP 4: CREATE CLEAN, CORRECT POLICIES
-- ============================================

-- 4.1. SELECT - Barcha authenticated userlar parts'ni o'qiy oladi
CREATE POLICY "parts_select"
ON public.parts
FOR SELECT
USING (auth.role() = 'authenticated');

-- 4.2. INSERT - Faqat manager va boss parts yaratishi mumkin
CREATE POLICY "parts_insert"
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

-- 4.3. UPDATE - Faqat manager va boss parts yangilashi mumkin
CREATE POLICY "parts_update"
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

-- 4.4. DELETE - Faqat manager va boss parts o'chirishi mumkin
CREATE POLICY "parts_delete"
ON public.parts
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role IN ('manager', 'boss')
  )
);

-- ============================================
-- STEP 5: REALTIME ACCESS FOR parts
-- ============================================

-- 5.1. Realtime enable (IF NOT EXISTS emas, chunki syntax error beradi)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'parts'
    AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.parts;
    RAISE NOTICE '✅ Realtime enabled for parts table';
  ELSE
    RAISE NOTICE '✅ Realtime already enabled for parts table';
  END IF;
END $$;

-- ============================================
-- STEP 6: VALIDATION QUERIES
-- ============================================

-- 6.1. RLS enabled ekanligini tekshirish
DO $$
DECLARE
  rls_enabled BOOLEAN;
  policies_count INTEGER;
BEGIN
  -- RLS enabled check
  SELECT rowsecurity INTO rls_enabled
  FROM pg_tables
  WHERE schemaname = 'public' AND tablename = 'parts';
  
  -- Policies count
  SELECT COUNT(*) INTO policies_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'parts';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PARTS PERMISSIONS FIX RESULTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RLS Enabled: %', rls_enabled;
  RAISE NOTICE 'Policies Count: %', policies_count;
  RAISE NOTICE '========================================';
  
  IF rls_enabled AND policies_count = 4 THEN
    RAISE NOTICE '✅ RLS and policies configured correctly';
  ELSE
    RAISE WARNING '⚠️ RLS or policies may need attention';
  END IF;
END $$;

-- 6.2. Users role distribution
SELECT 
  role,
  COUNT(*) as count
FROM public.users
GROUP BY role
ORDER BY role;

-- 6.3. Current user role check (test uchun)
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
-- ✅ FIX COMPLETE
-- ============================================
-- Endi:
-- 1. Users table role cleanup qilindi
-- 2. Missing users yaratildi
-- 3. Parts RLS to'liq reset qilindi
-- 4. To'g'ri policies yaratildi
-- 5. Realtime enabled
-- ============================================







