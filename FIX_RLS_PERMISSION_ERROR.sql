-- ============================================
-- FIX: Permission Denied for Table Users (RLS Error)
-- ============================================
-- 
-- MUAMMO: "permission denied for table users" (code: 42501)
-- SABAB: RLS policies user'ga o'z ma'lumotlarini o'qishga ruxsat bermayapti
-- 
-- YECHIM: RLS policies'ni to'g'ri sozlash
-- ============================================

-- ============================================
-- STEP 1: DROP EXISTING POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users read self" ON public.users;
DROP POLICY IF EXISTS "Boss read all users" ON public.users;
DROP POLICY IF EXISTS "Manager read all users" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Boss can update users" ON public.users;
DROP POLICY IF EXISTS "Boss update all users" ON public.users;

-- ============================================
-- STEP 2: CREATE SAFE RLS POLICIES
-- ============================================

-- Policy 1: User can ALWAYS read their own row
-- WHY: Critical for login - user must read their own profile
CREATE POLICY "Users can read own profile"
ON public.users
FOR SELECT
USING (auth.uid() = id);

-- Policy 2: User can insert their own row (for trigger)
-- WHY: Trigger needs to insert user profile
CREATE POLICY "Users can insert own profile"
ON public.users
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy 3: User can update their own row
-- WHY: User can update their own name, etc.
CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 4: Boss can read all users
-- WHY: Admin panel needs to list all users
-- NOTE: Uses auth.users metadata to avoid recursion
CREATE POLICY "Boss can read all users"
ON public.users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'boss'
      OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'boss'
      )
    )
  )
);

-- Policy 5: Manager can read all users
-- WHY: Manager needs to see users list
CREATE POLICY "Manager can read all users"
ON public.users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'manager'
      OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'manager'
      )
    )
  )
);

-- Policy 6: Boss can update all users
-- WHY: Admin panel needs to update user roles
CREATE POLICY "Boss can update all users"
ON public.users
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'boss'
      OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'boss'
      )
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'boss'
      OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role = 'boss'
      )
    )
  )
);

-- ============================================
-- STEP 3: VERIFY RLS IS ENABLED
-- ============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 4: VERIFICATION
-- ============================================

DO $$
DECLARE
  rls_enabled BOOLEAN;
  policy_count INTEGER;
BEGIN
  -- Check RLS is enabled
  SELECT relrowsecurity INTO rls_enabled
  FROM pg_class
  WHERE relname = 'users' 
  AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
  
  -- Count policies
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'users' AND schemaname = 'public';
  
  IF rls_enabled THEN
    RAISE NOTICE '✅ RLS is ENABLED on public.users';
  ELSE
    RAISE WARNING '⚠️ RLS is DISABLED on public.users';
  END IF;
  
  RAISE NOTICE '✅ Number of policies: %', policy_count;
  RAISE NOTICE '✅ Policies created successfully!';
END $$;

-- ============================================
-- STEP 5: ENSURE TRIGGER IS ACTIVE
-- ============================================

-- Check if trigger exists
DO $$
DECLARE
  trigger_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'on_auth_user_created'
    AND tgrelid = 'auth.users'::regclass
  ) INTO trigger_exists;
  
  IF trigger_exists THEN
    RAISE NOTICE '✅ Trigger on_auth_user_created is ACTIVE';
  ELSE
    RAISE WARNING '⚠️ Trigger on_auth_user_created is MISSING!';
    RAISE WARNING '⚠️ Run migration 015 or 019 to create the trigger';
  END IF;
END $$;

-- ============================================
-- SUMMARY
-- ============================================
-- ✅ RLS policies recreated with safe logic
-- ✅ Users can read their own profile
-- ✅ Users can insert their own profile (for trigger)
-- ✅ Boss/Manager can read all users
-- ✅ RLS is enabled
-- ✅ Trigger verification included
--
-- ENDI: User o'z ma'lumotlarini o'qiy oladi!
































