-- ============================================
-- BOSS USER FIX - Copy this SQL to Supabase SQL Editor
-- ============================================

-- STEP 1: Boss user'ni qo'lda yaratish
INSERT INTO public.users (id, name, email, role, created_at)
VALUES (
  '48ac9358-b302-4b01-9706-0c1600497a1c',
  'Boss',
  'boss@test.com',
  'boss',
  NOW()
)
ON CONFLICT (id) DO UPDATE
SET
  name = 'Boss',
  email = 'boss@test.com',
  role = 'boss',
  updated_at = NOW();

-- STEP 2: RLS yoqish
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- STEP 3: Eski policies'ni o'chirish
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Boss can update all users" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Users read self" ON public.users;
DROP POLICY IF EXISTS "Users insert self" ON public.users;
DROP POLICY IF EXISTS "Users update self" ON public.users;
DROP POLICY IF EXISTS "Boss read all users" ON public.users;
DROP POLICY IF EXISTS "Manager read all users" ON public.users;
DROP POLICY IF EXISTS "Boss update all users" ON public.users;

-- STEP 4: Yangi policies yaratish
CREATE POLICY "Users can read own profile"
ON public.users FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Boss and manager can read all users"
ON public.users FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.id = auth.uid()
    AND public.users.role IN ('boss', 'manager')
  )
);

CREATE POLICY "Users can insert own profile"
ON public.users FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Boss can update all users"
ON public.users FOR UPDATE
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

-- STEP 5: Tekshirish
SELECT id, email, role, name
FROM public.users 
WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';








