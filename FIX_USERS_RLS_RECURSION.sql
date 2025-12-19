-- ============================================
-- FIX: Infinite Recursion in Users RLS Policies
-- ============================================
-- 
-- MUAMMO: "infinite recursion detected in policy for relation users"
-- SABAB: Policy'da public.users jadvalidan o'qishga harakat qilinmoqda
-- 
-- YECHIM: auth.users metadata'dan o'qish (public.users emas)
-- ============================================

-- ============================================
-- STEP 1: Barcha eski policies'ni o'chirish
-- ============================================
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users read self" ON public.users;
DROP POLICY IF EXISTS "Boss can read all users" ON public.users;
DROP POLICY IF EXISTS "Manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users insert self" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Users update self" ON public.users;
DROP POLICY IF EXISTS "Boss can update users" ON public.users;
DROP POLICY IF EXISTS "Boss can update all users" ON public.users;
DROP POLICY IF EXISTS "Boss update all users" ON public.users;

-- ============================================
-- STEP 2: RLS'ni yoqish
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 3: YANGI RLS POLICIES (RECURSION YO'Q)
-- ============================================

-- Policy 1: User o'z ma'lumotlarini o'qishi mumkin
-- WHY: auth.uid() ishlatiladi - recursion yo'q
CREATE POLICY "Users can read own profile"
ON public.users
FOR SELECT
USING (auth.uid() = id);

-- Policy 2: Boss va Manager barcha userlarni o'qishi mumkin
-- WHY: auth.users metadata'dan o'qiladi (public.users emas) - recursion yo'q
CREATE POLICY "Boss and manager can read all users"
ON public.users
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'boss' OR
      auth.users.raw_user_meta_data->>'role' = 'manager'
    )
  )
);

-- Policy 3: User o'z ma'lumotlarini INSERT qilishi mumkin (trigger uchun)
-- WHY: auth.uid() ishlatiladi - recursion yo'q
CREATE POLICY "Users can insert own profile"
ON public.users
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy 4: User o'z ma'lumotlarini UPDATE qilishi mumkin
-- WHY: auth.uid() ishlatiladi - recursion yo'q
CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 5: Boss barcha userlarni UPDATE qilishi mumkin
-- WHY: auth.users metadata'dan o'qiladi (public.users emas) - recursion yo'q
CREATE POLICY "Boss can update all users"
ON public.users
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'role' = 'boss'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'role' = 'boss'
  )
);

-- ============================================
-- VERIFICATION
-- ============================================
-- Endi quyidagilar ishlashi kerak:
-- ✅ getUserById() - recursion yo'q
-- ✅ Auto-create user - recursion yo'q
-- ✅ Boss barcha userlarni ko'ra oladi
-- ✅ User o'z ma'lumotlarini yangilay oladi








