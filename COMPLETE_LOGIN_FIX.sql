-- ============================================
-- COMPLETE FIX: Login Database Permission Error
-- ============================================
-- 
-- MUAMMO: Login qilganda "database permission error"
-- SABABLAR:
-- 1. RLS policy recursion
-- 2. User public.users jadvalida mavjud emas
-- 3. INSERT permission yo'q
-- 
-- YECHIM: Barcha muammolarni bir vaqtda hal qilish
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

-- Policy 3: User o'z ma'lumotlarini INSERT qilishi mumkin (auto-create uchun)
-- WHY: auth.uid() ishlatiladi - recursion yo'q
-- MUHIM: Bu auto-create funksiyasi uchun zarur!
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
-- STEP 4: Mavjud userlarni sinxronlashtirish
-- ============================================
-- Barcha auth.users'dagi userlarni public.users'ga qo'shish
-- (Agar ular hali mavjud bo'lmasa)

INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  au.id,
  COALESCE(
    au.raw_user_meta_data->>'name',
    au.raw_user_meta_data->>'full_name',
    split_part(COALESCE(au.email, ''), '@', 1),
    'User'
  ) as name,
  COALESCE(au.email, '') as email,
  CASE 
    WHEN LOWER(COALESCE(au.email, '')) = 'manager@test.com' THEN 'manager'
    WHEN LOWER(COALESCE(au.email, '')) = 'boss@test.com' THEN 'boss'
    ELSE COALESCE(au.raw_user_meta_data->>'role', 'worker')
  END as role,
  COALESCE(au.created_at, NOW()) as created_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO UPDATE
SET
  name = COALESCE(EXCLUDED.name, public.users.name),
  email = COALESCE(EXCLUDED.email, public.users.email),
  role = CASE 
    WHEN LOWER(EXCLUDED.email) = 'manager@test.com' THEN 'manager'
    WHEN LOWER(EXCLUDED.email) = 'boss@test.com' THEN 'boss'
    ELSE COALESCE(EXCLUDED.role, public.users.role, 'worker')
  END,
  updated_at = NOW();

-- ============================================
-- STEP 5: Trigger'ni tekshirish va yangilash
-- ============================================

-- Trigger function'ni SECURITY DEFINER bilan yaratish/yangilash
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  user_role TEXT;
  user_name TEXT;
  user_email TEXT;
BEGIN
  -- Email ni olish
  user_email := COALESCE(NEW.email, '');
  
  -- Test accountlar uchun role'ni email'dan aniqlash
  IF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF NEW.raw_user_meta_data->>'role' IS NOT NULL THEN
    user_role := NEW.raw_user_meta_data->>'role';
  ELSE
    user_role := 'worker';
  END IF;
  
  -- Name ni olish
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  -- public.users jadvaliga INSERT qilish
  -- SECURITY DEFINER tufayli RLS o'tkazib yuboriladi
  INSERT INTO public.users (id, name, email, role, created_at)
  VALUES (
    NEW.id,
    user_name,
    user_email,
    user_role,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    name = COALESCE(EXCLUDED.name, public.users.name),
    email = COALESCE(EXCLUDED.email, public.users.email),
    role = CASE 
      WHEN LOWER(EXCLUDED.email) = 'manager@test.com' THEN 'manager'
      WHEN LOWER(EXCLUDED.email) = 'boss@test.com' THEN 'boss'
      ELSE COALESCE(EXCLUDED.role, public.users.role, 'worker')
    END,
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Trigger'ni qayta yaratish
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- VERIFICATION
-- ============================================
-- Endi quyidagilar ishlashi kerak:
-- ✅ Login qilganda user topiladi yoki yaratiladi
-- ✅ getUserById() - recursion yo'q
-- ✅ Auto-create user - permission error yo'q
-- ✅ Boss barcha userlarni ko'ra oladi
-- ✅ User o'z ma'lumotlarini yangilay oladi

-- Tekshirish uchun:
-- SELECT id, name, email, role FROM public.users;




