-- ============================================
-- BARAKAPARTS - SUPABASE DATABASE SCHEMA
-- ============================================
-- Bu fayl barcha jadvallarni yaratadi
-- SQL Editor ga nusxalab, bitta-bitta yoki to'liq bajarish mumkin
-- ============================================

-- ============================================
-- 1. USERS JADVALI
-- ============================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  role TEXT NOT NULL CHECK (role IN ('worker', 'manager', 'boss', 'supplier')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(phone),
  UNIQUE(email)
);

-- RLS yoqish
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Foydalanuvchilar o'z ma'lumotlarini ko'ra olishadi
DROP POLICY IF EXISTS "Users can read own data" ON users;
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);

-- Policy: Boss barcha foydalanuvchilarni ko'ra oladi
DROP POLICY IF EXISTS "Boss can read all users" ON users;
CREATE POLICY "Boss can read all users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'boss'
    )
  );

-- Policy: Boss foydalanuvchi yaratishi mumkin
DROP POLICY IF EXISTS "Boss can create users" ON users;
CREATE POLICY "Boss can create users" ON users
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'boss'
    )
  );

-- ============================================
-- 2. DEPARTMENTS JADVALI
-- ============================================
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS yoqish
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- Policy: Barcha autentifikatsiya qilingan foydalanuvchilar ko'ra oladi
DROP POLICY IF EXISTS "Authenticated users can read departments" ON departments;
CREATE POLICY "Authenticated users can read departments" ON departments
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy: Manager va Boss boshqara oladi
DROP POLICY IF EXISTS "Managers and boss can manage departments" ON departments;
CREATE POLICY "Managers and boss can manage departments" ON departments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss')
    )
  );

-- ============================================
-- 3. PARTS JADVALI
-- ============================================
CREATE TABLE IF NOT EXISTS parts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  min_quantity INTEGER NOT NULL DEFAULT 3,
  image_path TEXT,
  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Indexlar
CREATE INDEX IF NOT EXISTS idx_parts_name ON parts(name);
CREATE INDEX IF NOT EXISTS idx_parts_quantity ON parts(quantity);

-- RLS yoqish
ALTER TABLE parts ENABLE ROW LEVEL SECURITY;

-- Policy: Barcha autentifikatsiya qilingan foydalanuvchilar ko'ra oladi
DROP POLICY IF EXISTS "Authenticated users can read parts" ON parts;
CREATE POLICY "Authenticated users can read parts" ON parts
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy: Worker, Manager, Boss va Supplier yaratishi mumkin
DROP POLICY IF EXISTS "Authorized users can create parts" ON parts;
CREATE POLICY "Authorized users can create parts" ON parts
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('worker', 'manager', 'boss', 'supplier')
    )
  );

-- Policy: Manager, Boss va Supplier yangilashi mumkin
DROP POLICY IF EXISTS "Authorized users can update parts" ON parts;
CREATE POLICY "Authorized users can update parts" ON parts
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss', 'supplier')
    )
  );

-- Policy: Faqat Boss o'chirishi mumkin
DROP POLICY IF EXISTS "Boss can delete parts" ON parts;
CREATE POLICY "Boss can delete parts" ON parts
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'boss'
    )
  );

-- ============================================
-- 4. PRODUCTS JADVALI
-- ============================================
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  department_id UUID NOT NULL REFERENCES departments(id),
  parts_required JSONB NOT NULL DEFAULT '{}',
  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Indexlar
CREATE INDEX IF NOT EXISTS idx_products_department ON products(department_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);

-- RLS yoqish
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Policy: Barcha autentifikatsiya qilingan foydalanuvchilar ko'ra oladi
DROP POLICY IF EXISTS "Authenticated users can read products" ON products;
CREATE POLICY "Authenticated users can read products" ON products
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy: Manager va Boss boshqara oladi
DROP POLICY IF EXISTS "Managers and boss can manage products" ON products;
CREATE POLICY "Managers and boss can manage products" ON products
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss')
    )
  );

-- ============================================
-- 5. ORDERS JADVALI
-- ============================================
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  department_id UUID NOT NULL REFERENCES departments(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'rejected')),
  created_by UUID REFERENCES users(id),
  approved_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Indexlar
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_department ON orders(department_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

-- RLS yoqish
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: Barcha autentifikatsiya qilingan foydalanuvchilar ko'ra oladi
DROP POLICY IF EXISTS "Authenticated users can read orders" ON orders;
CREATE POLICY "Authenticated users can read orders" ON orders
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy: Barcha autentifikatsiya qilingan foydalanuvchilar yaratishi mumkin
DROP POLICY IF EXISTS "Authenticated users can create orders" ON orders;
CREATE POLICY "Authenticated users can create orders" ON orders
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Policy: Manager va Boss yangilashi mumkin
DROP POLICY IF EXISTS "Managers and boss can update orders" ON orders;
CREATE POLICY "Managers and boss can update orders" ON orders
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss')
    )
  );

-- ============================================
-- 6. LOGS JADVALI (AUDIT TRAIL)
-- ============================================
CREATE TABLE IF NOT EXISTS logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  action_type TEXT NOT NULL CHECK (action_type IN ('create', 'update', 'delete', 'approve', 'reject')),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('part', 'product', 'order', 'department', 'user')),
  entity_id UUID NOT NULL,
  before_value JSONB,
  after_value JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexlar
CREATE INDEX IF NOT EXISTS idx_logs_user ON logs(user_id);
CREATE INDEX IF NOT EXISTS idx_logs_entity ON logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_logs_created_at ON logs(created_at);

-- RLS yoqish
ALTER TABLE logs ENABLE ROW LEVEL SECURITY;

-- Policy: Foydalanuvchilar o'z loglarini ko'ra oladi
DROP POLICY IF EXISTS "Users can see own logs" ON logs;
CREATE POLICY "Users can see own logs" ON logs
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Manager va Boss barcha loglarni ko'ra oladi
DROP POLICY IF EXISTS "Managers and boss can see all logs" ON logs;
CREATE POLICY "Managers and boss can see all logs" ON logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss')
    )
  );

-- Policy: Tizim log yaratishi mumkin
DROP POLICY IF EXISTS "System can create logs" ON logs;
CREATE POLICY "System can create logs" ON logs
  FOR INSERT WITH CHECK (true);

-- ============================================
-- 7. REALTIME YOQISH
-- ============================================
-- Real-time yangilanishlar uchun
ALTER PUBLICATION supabase_realtime ADD TABLE parts;
ALTER PUBLICATION supabase_realtime ADD TABLE products;
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE departments;
ALTER PUBLICATION supabase_realtime ADD TABLE logs;

-- ============================================
-- 8. TEST MA'LUMOTLARI (Ixtiyoriy)
-- ============================================
-- Test bo'limlar
INSERT INTO departments (name) VALUES
  ('Assembly'),
  ('Packaging'),
  ('Quality Control')
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- TUGADI!
-- ============================================
-- Endi Table Editor da barcha jadvallar ko'rinishi kerak
-- ============================================

