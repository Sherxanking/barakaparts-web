# BarakaParts Refactoring Guide

## Overview

This document provides a comprehensive guide for completing the refactoring of BarakaParts from a local Hive-based app to a multi-user, role-based, real-time Supabase-backed enterprise system.

## Architecture

The project now follows Clean Architecture:

```
lib/
├── core/                    # Core utilities, errors, constants
│   ├── errors/
│   └── utils/
├── domain/                  # Business logic layer (framework-independent)
│   ├── entities/           # Pure Dart entities
│   ├── repositories/      # Repository interfaces
│   └── permissions/        # Permission logic
├── infrastructure/          # External concerns
│   ├── datasources/        # Supabase & Hive datasources
│   ├── cache/              # Hive cache implementations
│   ├── models/             # Hive models
│   └── repositories/       # Repository implementations
├── application/            # Use cases / services
│   └── services/           # Application services
└── presentation/           # UI layer (existing)
    ├── pages/
    └── widgets/
```

## Supabase Database Schema

Run these SQL commands in your Supabase SQL Editor:

### 1. Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  role TEXT NOT NULL CHECK (role IN ('worker', 'manager', 'boss', 'supplier')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(phone),
  UNIQUE(email)
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own data
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);

-- Policy: Boss can read all users
CREATE POLICY "Boss can read all users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'boss'
    )
  );
```

### 2. Parts Table

```sql
CREATE TABLE parts (
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

CREATE INDEX idx_parts_name ON parts(name);
CREATE INDEX idx_parts_quantity ON parts(quantity);

ALTER TABLE parts ENABLE ROW LEVEL SECURITY;

-- Policy: All authenticated users can read parts
CREATE POLICY "Authenticated users can read parts" ON parts
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy: Workers, managers, boss, and suppliers can create parts
CREATE POLICY "Authorized users can create parts" ON parts
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('worker', 'manager', 'boss', 'supplier')
    )
  );

-- Policy: Managers, boss, and suppliers can update parts
CREATE POLICY "Authorized users can update parts" ON parts
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss', 'supplier')
    )
  );
```

### 3. Products Table

```sql
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  department_id UUID NOT NULL REFERENCES departments(id),
  parts_required JSONB NOT NULL DEFAULT '{}',
  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE INDEX idx_products_department ON products(department_id);
CREATE INDEX idx_products_name ON products(name);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read products" ON products
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can manage products" ON products
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss')
    )
  );
```

### 4. Departments Table

```sql
CREATE TABLE departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read departments" ON departments
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can manage departments" ON departments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss')
    )
  );
```

### 5. Orders Table

```sql
CREATE TABLE orders (
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

CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_department ON orders(department_id);
CREATE INDEX idx_orders_created_at ON orders(created_at);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read orders" ON orders
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create orders" ON orders
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Managers and boss can update orders" ON orders
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss')
    )
  );
```

### 6. Logs Table (Audit Trail)

```sql
CREATE TABLE logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  action_type TEXT NOT NULL CHECK (action_type IN ('create', 'update', 'delete', 'approve', 'reject')),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('part', 'product', 'order', 'department', 'user')),
  entity_id UUID NOT NULL,
  before_value JSONB,
  after_value JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_logs_user ON logs(user_id);
CREATE INDEX idx_logs_entity ON logs(entity_type, entity_id);
CREATE INDEX idx_logs_created_at ON logs(created_at);

ALTER TABLE logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own logs
CREATE POLICY "Users can see own logs" ON logs
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Managers and boss can see all logs
CREATE POLICY "Managers and boss can see all logs" ON logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('manager', 'boss')
    )
  );

-- Policy: System can create logs (via service role)
CREATE POLICY "System can create logs" ON logs
  FOR INSERT WITH CHECK (true);
```

### 7. Enable Realtime

```sql
-- Enable realtime for all tables
ALTER PUBLICATION supabase_realtime ADD TABLE parts;
ALTER PUBLICATION supabase_realtime ADD TABLE products;
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE departments;
ALTER PUBLICATION supabase_realtime ADD TABLE logs;
```

## Remaining Implementation Tasks

### 1. Complete Infrastructure Layer

Create remaining datasources and repositories following the pattern in `part_repository_impl.dart`:

- [ ] `supabase_department_datasource.dart`
- [ ] `supabase_user_datasource.dart`
- [ ] `supabase_log_datasource.dart`
- [ ] `hive_product_cache.dart`
- [ ] `hive_order_cache.dart`
- [ ] `hive_department_cache.dart`
- [ ] `product_repository_impl.dart`
- [ ] `order_repository_impl.dart`
- [ ] `department_repository_impl.dart`
- [ ] `user_repository_impl.dart`
- [ ] `log_repository_impl.dart`

### 2. Application Services Layer

Create use cases in `lib/application/services/`:

- [ ] `auth_service.dart` - Authentication & user management
- [ ] `part_service.dart` - Part operations with permissions
- [ ] `product_service.dart` - Product operations with permissions
- [ ] `order_service.dart` - Order operations with audit logging
- [ ] `analytics_service.dart` - Analytics and reporting
- [ ] `audit_service.dart` - Automatic audit logging

### 3. UI Fixes

#### Parts Page (`lib/presentation/pages/parts_page.dart`)

- [ ] Replace icon buttons with PopupMenuButton (three dots)
- [ ] Fix overflow issues - ensure quantity and names are always visible
- [ ] Add debounced search (300ms delay)

#### Orders Page (`lib/presentation/pages/orders_page.dart`)

- [ ] Fix RefreshIndicator scrolling conflict
- [ ] Use optimized ListView with proper physics
- [ ] Add "This month total produced" display

#### Product Edit Page (`lib/presentation/pages/product_edit_page.dart`)

- [ ] Fix crash when editing parts list
- [ ] Ensure proper JSON mapping
- [ ] Add validation

### 4. Multi-Language Support

- [ ] Create ARB files for Uzbek, Russian, English
- [ ] Update `lib/l10n/` with all strings
- [ ] Add language switcher in Settings page
- [ ] Remove all hardcoded strings

### 5. Authentication Flow

- [ ] Create login page
- [ ] Implement Supabase authentication
- [ ] Add user session management
- [ ] Protect routes based on roles

### 6. Real-time Updates

- [ ] Integrate Supabase realtime streams in repositories
- [ ] Update UI to listen to streams
- [ ] Handle connection errors gracefully

### 7. Analytics Dashboard

- [ ] Create analytics page
- [ ] Implement monthly production reports
- [ ] Add department-based reporting
- [ ] Show parts usage history

## Migration Steps

1. **Set up Supabase**:
   - Create Supabase project
   - Run SQL schema above
   - Get URL and anon key
   - Update `lib/core/utils/constants.dart`

2. **Update main.dart**:
   - Initialize Supabase before Hive
   - Add authentication check
   - Handle initialization errors

3. **Gradual Migration**:
   - Start with Parts (already implemented as example)
   - Migrate Products
   - Migrate Orders
   - Migrate Departments
   - Add Users and Logs

4. **Update UI**:
   - Replace direct service calls with repository calls
   - Add loading states
   - Add error handling
   - Add permission checks

## Environment Variables

Create `.env` file (add to `.gitignore`):

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Or use `--dart-define` flags:

```bash
flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
```

## Testing Checklist

- [ ] All CRUD operations work with Supabase
- [ ] Offline mode works with Hive cache
- [ ] Real-time updates work
- [ ] Permissions are enforced
- [ ] Audit logs are created
- [ ] UI fixes are implemented
- [ ] Multi-language works
- [ ] No crashes or errors

## Next Steps

1. Complete the remaining datasources and repositories
2. Implement application services
3. Fix UI issues
4. Add authentication
5. Test thoroughly
6. Deploy

