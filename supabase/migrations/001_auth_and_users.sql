-- ============================================
-- STEP 1: Auth + Rollar Tuzilmasi
-- ============================================
-- Bu migration fayl Supabase da bajariladi
-- ============================================

-- ============================================
-- 1. USERS JADVALI (Agar mavjud bo'lsa, o'zgartirish)
-- ============================================

-- Avval mavjud jadvalni tekshirish
DO $$ 
BEGIN
  -- Agar users jadvali mavjud bo'lsa, department_id qo'shish
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
    -- department_id ustuni mavjud emas bo'lsa, qo'shish
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'department_id'
    ) THEN
      ALTER TABLE users ADD COLUMN department_id UUID REFERENCES departments(id);
      CREATE INDEX IF NOT EXISTS idx_users_department ON users(department_id);
    END IF;
  ELSE
    -- Agar users jadvali yo'q bo'lsa, yaratish
    CREATE TABLE users (
      id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      email TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      phone TEXT,
      role TEXT NOT NULL CHECK (role IN ('boss', 'manager', 'worker', 'supplier')),
      department_id UUID REFERENCES departments(id),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Indexlar
    CREATE INDEX idx_users_role ON users(role);
    CREATE INDEX idx_users_department ON users(department_id);
  END IF;
END $$;

-- RLS yoqish (agar yo'q bo'lsa)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. RLS POLICY LAR
-- ============================================

-- Eski policy larni o'chirish (agar mavjud bo'lsa)
DROP POLICY IF EXISTS "Users can read own data" ON users;
DROP POLICY IF EXISTS "Boss can read all users" ON users;
DROP POLICY IF EXISTS "Manager can read department users" ON users;
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Boss can update users" ON users;

-- Policy 1: Har bir user o'z ma'lumotlarini ko'ra oladi
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);

-- Policy 2: Boss barcha userlarni ko'ra oladi
CREATE POLICY "Boss can read all users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'boss'
    )
  );

-- Policy 3: Manager o'z bo'limidagi userlarni ko'ra oladi
CREATE POLICY "Manager can read department users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users u1
      WHERE u1.id = auth.uid() 
      AND u1.role = 'manager'
      AND u1.department_id = users.department_id
    )
  );

-- Policy 4: User o'zini yaratishi mumkin (signup paytida)
CREATE POLICY "Users can insert own data" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Policy 5: Boss userlarni yangilashi mumkin
CREATE POLICY "Boss can update users" ON users
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'boss'
    )
  );

-- ============================================
-- 3. FUNCTION: Auto-create user on signup
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, department_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'worker')::text,
    (NEW.raw_user_meta_data->>'department_id')::uuid
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Auth user yaratilganda users jadvaliga qo'shish
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 4. DEPARTMENTS JADVALI (Agar mavjud bo'lsa, o'zgartirish)
-- ============================================
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'departments') THEN
    CREATE TABLE departments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL UNIQUE,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

    -- Barcha authenticated userlar ko'ra oladi
    CREATE POLICY "Authenticated users can read departments" ON departments
      FOR SELECT USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ============================================
-- TUGADI!
-- ============================================




