-- ============================================
-- COMPLETE FINAL MIGRATION - Barcha Muammolarni Hal Qilish
-- ============================================
-- 
-- Bu bitta to'liq migration - barcha eski migration'larni o'rnini bosadi
-- 
-- QADAM 1: Supabase Dashboard → SQL Editor
-- QADAM 2: Bu SQL'ni nusxalab, RUN qiling
-- QADAM 3: Barcha eski migration fayllarni o'chiring
-- 
-- ============================================

-- ============================================
-- STEP 1: BARCHA ESKI POLICIES'NI O'CHIRISH
-- ============================================
-- Avval barcha eski policies'ni tozalash (conflict'larni oldini olish)

-- Users jadvali
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.users';
  END LOOP;
END $$;

-- Parts jadvali
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'parts') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.parts';
  END LOOP;
END $$;

-- Products jadvali
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'products') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.products';
  END LOOP;
END $$;

-- Orders jadvali
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'orders') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.orders';
  END LOOP;
END $$;

-- Departments jadvali
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'departments') LOOP
    EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON public.departments';
  END LOOP;
END $$;

-- ============================================
-- STEP 2: USERS TABLE - RLS POLICIES (RECURSION YO'Q)
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policy 1: User o'z ma'lumotlarini o'qishi mumkin
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
-- NULL va invalid role'larni tuzatish
UPDATE public.users
SET role = 'manager'
WHERE LOWER(email) = 'manager@test.com' AND (role IS NULL OR role = '' OR role != 'manager');

UPDATE public.users
SET role = 'boss'
WHERE LOWER(email) = 'boss@test.com' AND (role IS NULL OR role = '' OR role != 'boss');

UPDATE public.users
SET role = 'worker'
WHERE (role IS NULL OR role = '' OR role NOT IN ('worker', 'manager', 'boss', 'supplier'))
  AND LOWER(email) NOT IN ('manager@test.com', 'boss@test.com');

-- NOT NULL va DEFAULT qo'shish (xavfsiz)
DO $$
BEGIN
  -- NULL'larni to'ldirish
  UPDATE public.users SET role = 'worker' WHERE role IS NULL;
  
  -- NOT NULL constraint (agar hali yo'q bo'lsa)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'users' 
    AND column_name = 'role' AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE public.users ALTER COLUMN role SET NOT NULL;
  END IF;
  
  -- DEFAULT value (agar hali yo'q bo'lsa)
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
  ELSIF NEW.raw_user_meta_data->>'role' IS NOT NULL AND NEW.raw_user_meta_data->>'role' != '' THEN
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
  -- Parts
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'parts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE parts;
  END IF;
  
  -- Products
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE products;
  END IF;
  
  -- Orders
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
-- Barcha auth.users'dagi userlarni public.users'ga qo'shish
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
  users_policies INTEGER;
  parts_policies INTEGER;
  products_policies INTEGER;
  orders_policies INTEGER;
  departments_policies INTEGER;
  null_roles INTEGER;
  total_users INTEGER;
BEGIN
  SELECT COUNT(*) INTO users_policies FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users';
  SELECT COUNT(*) INTO parts_policies FROM pg_policies WHERE schemaname = 'public' AND tablename = 'parts';
  SELECT COUNT(*) INTO products_policies FROM pg_policies WHERE schemaname = 'public' AND tablename = 'products';
  SELECT COUNT(*) INTO orders_policies FROM pg_policies WHERE schemaname = 'public' AND tablename = 'orders';
  SELECT COUNT(*) INTO departments_policies FROM pg_policies WHERE schemaname = 'public' AND tablename = 'departments';
  SELECT COUNT(*) INTO null_roles FROM public.users WHERE role IS NULL;
  SELECT COUNT(*) INTO total_users FROM public.users;
  
  RAISE NOTICE '✅ Users policies: %', users_policies;
  RAISE NOTICE '✅ Parts policies: %', parts_policies;
  RAISE NOTICE '✅ Products policies: %', products_policies;
  RAISE NOTICE '✅ Orders policies: %', orders_policies;
  RAISE NOTICE '✅ Departments policies: %', departments_policies;
  RAISE NOTICE '✅ NULL roles: %', null_roles;
  RAISE NOTICE '✅ Total users: %', total_users;
  RAISE NOTICE '✅ Migration muvaffaqiyatli yakunlandi!';
END $$;

