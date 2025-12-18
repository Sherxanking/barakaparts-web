-- ============================================
-- FINAL CLEAN MIGRATION - Barcha Muammolarni Hal Qilish
-- ============================================
-- 
-- MUAMMO: Ko'p migration'lar bir-biriga conflict qilmoqda
-- SABAB: Har bir migration o'z policies'larini yaratmoqda
-- 
-- YECHIM: Barcha eski policies'ni o'chirib, bitta to'liq migration yaratish
-- ============================================

-- ============================================
-- STEP 1: BARCHA ESKI POLICIES'NI O'CHIRISH
-- ============================================
-- Users jadvali uchun
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.users';
  END LOOP;
  RAISE NOTICE '✅ Barcha users policies o''chirildi';
END $$;

-- Parts jadvali uchun
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'parts') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.parts';
  END LOOP;
  RAISE NOTICE '✅ Barcha parts policies o''chirildi';
END $$;

-- Products jadvali uchun
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'products') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.products';
  END LOOP;
  RAISE NOTICE '✅ Barcha products policies o''chirildi';
END $$;

-- Orders jadvali uchun
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'orders') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.orders';
  END LOOP;
  RAISE NOTICE '✅ Barcha orders policies o''chirildi';
END $$;

-- Departments jadvali uchun
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'departments') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.departments';
  END LOOP;
  RAISE NOTICE '✅ Barcha departments policies o''chirildi';
END $$;

-- ============================================
-- STEP 2: USERS TABLE - RLS POLICIES
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

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
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (
      auth.users.raw_user_meta_data->>'role' = 'boss' OR
      auth.users.raw_user_meta_data->>'role' = 'manager'
    )
  )
);

-- Policy 3: User o'z ma'lumotlarini INSERT qilishi mumkin (auto-create uchun)
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
-- STEP 3: USERS TABLE - ROLE COLUMN FIX
-- ============================================
-- NULL role'larni to'ldirish
UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com' AND (role IS NULL OR role = '');

UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com' AND (role IS NULL OR role = '');

UPDATE public.users
SET role = 'worker'
WHERE (role IS NULL OR role = '')
  AND LOWER(email) NOT IN ('manager@test.com', 'boss@test.com');

-- Invalid role'larni tuzatish
UPDATE public.users
SET role = 'worker'
WHERE role NOT IN ('worker', 'manager', 'boss', 'supplier')
  AND LOWER(email) NOT IN ('manager@test.com', 'boss@test.com');

-- NOT NULL va DEFAULT qo'shish (xavfsiz)
DO $$
BEGIN
  -- NULL'larni to'ldirish
  UPDATE public.users SET role = 'worker' WHERE role IS NULL;
  
  -- NOT NULL constraint
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'users' 
    AND column_name = 'role' AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE public.users ALTER COLUMN role SET NOT NULL;
  END IF;
  
  -- DEFAULT value
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'users' 
    AND column_name = 'role' AND column_default IS NOT NULL
  ) THEN
    ALTER TABLE public.users ALTER COLUMN role SET DEFAULT 'worker';
  END IF;
END $$;

-- ============================================
-- STEP 4: TRIGGER FUNCTION (YAKUNIY VERSIYA)
-- ============================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

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
  user_email := COALESCE(NEW.email, '');
  
  -- Test accountlar
  IF LOWER(user_email) = 'manager@test.com' THEN
    user_role := 'manager';
  ELSIF LOWER(user_email) = 'boss@test.com' THEN
    user_role := 'boss';
  ELSIF NEW.raw_user_meta_data->>'role' IS NOT NULL THEN
    user_role := NEW.raw_user_meta_data->>'role';
  ELSE
    user_role := 'worker';
  END IF;
  
  -- Validatsiya
  IF user_role NOT IN ('worker', 'manager', 'boss', 'supplier') THEN
    user_role := 'worker';
  END IF;
  
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(user_email, '@', 1),
    'User'
  );
  
  INSERT INTO public.users (id, name, email, role, created_at)
  VALUES (NEW.id, user_name, user_email, user_role, NOW())
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
    RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 5: PARTS TABLE - RLS POLICIES
-- ============================================
ALTER TABLE public.parts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read parts"
ON public.parts
FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Authorized users can create parts"
ON public.parts
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss', 'supplier')
  )
);

CREATE POLICY "Authorized users can update parts"
ON public.parts
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss', 'supplier')
  )
);

-- ============================================
-- STEP 6: PRODUCTS TABLE - RLS POLICIES
-- ============================================
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read products"
ON public.products
FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can manage products"
ON public.products
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
  )
);

-- ============================================
-- STEP 7: ORDERS TABLE - RLS POLICIES
-- ============================================
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read orders"
ON public.orders
FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create orders"
ON public.orders
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can update orders"
ON public.orders
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND auth.users.raw_user_meta_data->>'role' IN ('manager', 'boss')
  )
);

-- ============================================
-- STEP 8: DEPARTMENTS TABLE - RLS POLICIES
-- ============================================
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read departments"
ON public.departments
FOR SELECT
USING (auth.role() = 'authenticated');

-- ============================================
-- STEP 9: REALTIME ENABLE
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'parts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE parts;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE products;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE orders;
  END IF;
END $$;

-- ============================================
-- STEP 10: MAVJUD USERLARNI SINXRONLASHTIRISH
-- ============================================
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
-- VERIFICATION
-- ============================================
DO $$
DECLARE
  users_policies_count INTEGER;
  parts_policies_count INTEGER;
  products_policies_count INTEGER;
  orders_policies_count INTEGER;
  departments_policies_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO users_policies_count FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users';
  SELECT COUNT(*) INTO parts_policies_count FROM pg_policies WHERE schemaname = 'public' AND tablename = 'parts';
  SELECT COUNT(*) INTO products_policies_count FROM pg_policies WHERE schemaname = 'public' AND tablename = 'products';
  SELECT COUNT(*) INTO orders_policies_count FROM pg_policies WHERE schemaname = 'public' AND tablename = 'orders';
  SELECT COUNT(*) INTO departments_policies_count FROM pg_policies WHERE schemaname = 'public' AND tablename = 'departments';
  
  RAISE NOTICE '✅ Users policies: %', users_policies_count;
  RAISE NOTICE '✅ Parts policies: %', parts_policies_count;
  RAISE NOTICE '✅ Products policies: %', products_policies_count;
  RAISE NOTICE '✅ Orders policies: %', orders_policies_count;
  RAISE NOTICE '✅ Departments policies: %', departments_policies_count;
  RAISE NOTICE '✅ Migration muvaffaqiyatli yakunlandi!';
END $$;







