-- ============================================
-- FIX: RLS Infinite Recursion Error
-- ============================================
-- 
-- MUAMMO: "infinite recursion detected in policy for relation users"
-- SABAB: Policy o'zi users jadvalini tekshirganda yana o'sha policy ishga tushadi
-- 
-- YECHIM: SECURITY DEFINER function yaratib, role check qilish
-- ============================================

-- STEP 1: Helper function yaratish (SECURITY DEFINER - RLS o'tkazib yuboradi)
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT role FROM public.users WHERE id = user_id;
$$;

-- STEP 2: Eski policies'ni o'chirish
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

-- STEP 3: Yangi policies yaratish (recursion yo'q)
-- Policy 1: User o'z ma'lumotlarini o'qishi mumkin
CREATE POLICY "Users can read own profile"
ON public.users FOR SELECT
USING (auth.uid() = id);

-- Policy 2: Boss va Manager barcha userlarni o'qishi mumkin
-- SECURITY DEFINER function ishlatamiz (recursion yo'q)
CREATE POLICY "Boss and manager can read all users"
ON public.users FOR SELECT
USING (
  public.get_user_role(auth.uid()) IN ('boss', 'manager')
);

-- Policy 3: User o'z ma'lumotlarini INSERT qilishi mumkin
CREATE POLICY "Users can insert own profile"
ON public.users FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy 4: User o'z ma'lumotlarini UPDATE qilishi mumkin
CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 5: Boss barcha userlarni UPDATE qilishi mumkin
-- SECURITY DEFINER function ishlatamiz (recursion yo'q)
CREATE POLICY "Boss can update all users"
ON public.users FOR UPDATE
USING (public.get_user_role(auth.uid()) = 'boss')
WITH CHECK (public.get_user_role(auth.uid()) = 'boss');

-- STEP 4: Boss user'ni yaratish/yangilash
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

-- STEP 5: Tekshirish
SELECT id, email, role, name
FROM public.users 
WHERE id = '48ac9358-b302-4b01-9706-0c1600497a1c';






























