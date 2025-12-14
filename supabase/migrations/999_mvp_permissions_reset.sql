-- ============================================
-- Migration 999: MVP Permissions Reset - HARD FIX
-- ============================================
-- 
-- GOAL: STABLE, SIMPLE, WORKING MVP
-- ONLY Google login, 3 roles, simple RLS
-- ============================================

-- ============================================
-- STEP 1: USERS TABLE HARD FIX
-- ============================================

-- 1.1. Ensure users table exists with correct structure
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'users'
  ) THEN
    CREATE TABLE public.users (
      id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      email TEXT,
      role TEXT NOT NULL DEFAULT 'worker',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    RAISE NOTICE '✅ Users table created';
  ELSE
    RAISE NOTICE '✅ Users table already exists';
  END IF;
  
  -- Ensure role column exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'role'
  ) THEN
    ALTER TABLE public.users ADD COLUMN role TEXT NOT NULL DEFAULT 'worker';
    RAISE NOTICE '✅ Role column added';
  END IF;
END $$;

-- 1.2. HARD FIX: Clean up all invalid roles
UPDATE public.users
SET role = 'worker'
WHERE role IS NULL 
   OR role = ''
   OR role NOT IN ('worker', 'manager', 'boss');

-- 1.3. Ensure role constraint
DO $$
BEGIN
  -- Drop existing constraint if exists
  ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
  
  -- Add correct constraint
  ALTER TABLE public.users 
  ADD CONSTRAINT users_role_check 
  CHECK (role IN ('worker', 'manager', 'boss'));
  
  RAISE NOTICE '✅ Role constraint set';
END $$;

-- 1.4. Sync missing users from auth.users
INSERT INTO public.users (id, email, role, created_at)
SELECT 
  au.id,
  au.email,
  CASE 
    WHEN LOWER(COALESCE(au.email, '')) = 'manager@test.com' THEN 'manager'
    WHEN LOWER(COALESCE(au.email, '')) = 'boss@test.com' THEN 'boss'
    WHEN EXISTS (
      SELECT 1 FROM auth.identities ai 
      WHERE ai.user_id = au.id AND ai.provider = 'google'
    ) THEN 'manager'  -- Google users get manager role
    ELSE 'worker'
  END as role,
  COALESCE(au.created_at, NOW()) as created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO UPDATE
SET
  email = EXCLUDED.email,
  role = CASE 
    WHEN LOWER(EXCLUDED.email) = 'manager@test.com' THEN 'manager'
    WHEN LOWER(EXCLUDED.email) = 'boss@test.com' THEN 'boss'
    ELSE EXCLUDED.role
  END;

-- 1.5. Users table RLS policies
-- MUHIM: Trigger ishlashi uchun zarur!
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Eski policies'ni o'chirish
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Boss can update all users" ON public.users;

-- Policy 1: User o'z ma'lumotlarini o'qishi mumkin
CREATE POLICY "Users can read own profile"
ON public.users
FOR SELECT
USING (auth.uid() = id);

-- Policy 2: Boss va Manager barcha userlarni o'qishi mumkin
CREATE POLICY "Boss and manager can read all users"
ON public.users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role IN ('boss', 'manager')
  )
);

-- Policy 3: User o'z ma'lumotlarini INSERT qilishi mumkin (trigger uchun)
CREATE POLICY "Users can insert own profile"
ON public.users
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy 4: User o'z ma'lumotlarini UPDATE qilishi mumkin
CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 5: Boss barcha userlarni UPDATE qilishi mumkin
CREATE POLICY "Boss can update all users"
ON public.users
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role = 'boss'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role = 'boss'
  )
);

-- ============================================
-- STEP 2: PARTS TABLE PERMISSION RESET
-- ============================================

-- 2.1. Ensure parts table exists
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
    
    CREATE INDEX IF NOT EXISTS idx_parts_name ON public.parts(name);
    CREATE INDEX IF NOT EXISTS idx_parts_created_by ON public.parts(created_by);
    
    RAISE NOTICE '✅ Parts table created';
  ELSE
    RAISE NOTICE '✅ Parts table already exists';
  END IF;
END $$;

-- 2.2. FULL RLS RESET
ALTER TABLE public.parts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;

-- 2.3. DROP ALL EXISTING POLICIES
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
-- STEP 3: CREATE SIMPLE, CORRECT POLICIES
-- ============================================

-- 3.1. SELECT - All authenticated users
CREATE POLICY "parts_select"
ON public.parts
FOR SELECT
USING (auth.role() = 'authenticated');

-- 3.2. INSERT - Only manager and boss
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

-- 3.3. UPDATE - Only manager and boss
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

-- 3.4. DELETE - Only manager and boss
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
-- STEP 4: REALTIME ENABLE
-- ============================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'parts'
    AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.parts;
    RAISE NOTICE '✅ Realtime enabled for parts';
  ELSE
    RAISE NOTICE '✅ Realtime already enabled for parts';
  END IF;
END $$;

-- ============================================
-- STEP 5: VALIDATION
-- ============================================

DO $$
DECLARE
  rls_enabled BOOLEAN;
  policies_count INTEGER;
  users_count INTEGER;
BEGIN
  -- RLS check
  SELECT rowsecurity INTO rls_enabled
  FROM pg_tables
  WHERE schemaname = 'public' AND tablename = 'parts';
  
  -- Policies count
  SELECT COUNT(*) INTO policies_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'parts';
  
  -- Users count
  SELECT COUNT(*) INTO users_count
  FROM public.users;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'MVP PERMISSIONS RESET RESULTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RLS Enabled: %', rls_enabled;
  RAISE NOTICE 'Policies Count: %', policies_count;
  RAISE NOTICE 'Total Users: %', users_count;
  RAISE NOTICE '========================================';
  
  IF rls_enabled AND policies_count = 4 THEN
    RAISE NOTICE '✅ MVP permissions configured correctly';
  ELSE
    RAISE WARNING '⚠️ Configuration may need attention';
  END IF;
END $$;

-- ============================================
-- ✅ MVP RESET COMPLETE
-- ============================================
-- Endi:
-- 1. Users table cleaned and synced
-- 2. Parts RLS reset and simple policies created
-- 3. Realtime enabled
-- 4. Ready for Google-only login
-- ============================================

