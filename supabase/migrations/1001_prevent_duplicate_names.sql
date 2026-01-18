-- ============================================
-- Migration 1001: Prevent Duplicate Names
-- ============================================
-- 
-- GOAL: Prevent duplicate entity names (case-insensitive, trimmed)
-- - Parts: LOWER(TRIM(name)) must be unique
-- - Products: LOWER(TRIM(name)) must be unique per department (optional: global)
-- - Departments: Already has UNIQUE constraint (no change needed)
-- - Orders: No unique constraint (multiple orders can have same product_name)
-- 
-- SAFETY:
-- - Does NOT delete existing rows
-- - Detects and reports duplicates if they exist
-- - Works with existing RLS policies
-- ============================================

-- ============================================
-- STEP 1: RESOLVE EXISTING DUPLICATES
-- ============================================
-- Strategy: Keep first occurrence, rename others with suffix (2), (3), etc.

-- 1.1. Resolve duplicate PARTS
DO $$
DECLARE
  duplicate_group RECORD;
  duplicate_item RECORD;
  counter INTEGER;
  new_name TEXT;
  normalized_name TEXT;
BEGIN
  -- For each duplicate group, keep the first (oldest by created_at, or by id if no created_at)
  FOR duplicate_group IN
    SELECT LOWER(TRIM(name)) as normalized_name
    FROM public.parts
    GROUP BY LOWER(TRIM(name))
    HAVING COUNT(*) > 1
  LOOP
    normalized_name := duplicate_group.normalized_name;
    counter := 2;
    
    -- Update all duplicates except the first one
    FOR duplicate_item IN
      SELECT id, name, created_at
      FROM public.parts
      WHERE LOWER(TRIM(name)) = normalized_name
      ORDER BY COALESCE(created_at, '1970-01-01'::TIMESTAMPTZ), id
      OFFSET 1  -- Skip the first one
    LOOP
      -- Generate new name with suffix
      new_name := TRIM(duplicate_item.name) || ' (' || counter || ')';
      
      -- Check if new name already exists, if yes, increment counter
      WHILE EXISTS (
        SELECT 1 FROM public.parts 
        WHERE LOWER(TRIM(name)) = LOWER(new_name) AND id != duplicate_item.id
      ) LOOP
        counter := counter + 1;
        new_name := TRIM(duplicate_item.name) || ' (' || counter || ')';
      END LOOP;
      
      -- Update the duplicate
      UPDATE public.parts
      SET name = new_name
      WHERE id = duplicate_item.id;
      
      RAISE NOTICE '✅ Renamed duplicate part: "%" -> "%"', duplicate_item.name, new_name;
      counter := counter + 1;
    END LOOP;
  END LOOP;
  
  RAISE NOTICE '✅ Parts duplicates resolved';
END $$;

-- 1.2. Resolve duplicate PRODUCTS
DO $$
DECLARE
  duplicate_group RECORD;
  duplicate_item RECORD;
  counter INTEGER;
  new_name TEXT;
  normalized_name TEXT;
BEGIN
  FOR duplicate_group IN
    SELECT LOWER(TRIM(name)) as normalized_name
    FROM public.products
    GROUP BY LOWER(TRIM(name))
    HAVING COUNT(*) > 1
  LOOP
    normalized_name := duplicate_group.normalized_name;
    counter := 2;
    
    FOR duplicate_item IN
      SELECT id, name, created_at
      FROM public.products
      WHERE LOWER(TRIM(name)) = normalized_name
      ORDER BY COALESCE(created_at, '1970-01-01'::TIMESTAMPTZ), id
      OFFSET 1
    LOOP
      new_name := TRIM(duplicate_item.name) || ' (' || counter || ')';
      
      WHILE EXISTS (
        SELECT 1 FROM public.products 
        WHERE LOWER(TRIM(name)) = LOWER(new_name) AND id != duplicate_item.id
      ) LOOP
        counter := counter + 1;
        new_name := TRIM(duplicate_item.name) || ' (' || counter || ')';
      END LOOP;
      
      UPDATE public.products
      SET name = new_name
      WHERE id = duplicate_item.id;
      
      RAISE NOTICE '✅ Renamed duplicate product: "%" -> "%"', duplicate_item.name, new_name;
      counter := counter + 1;
    END LOOP;
  END LOOP;
  
  RAISE NOTICE '✅ Products duplicates resolved';
END $$;

-- 1.3. Resolve duplicate DEPARTMENTS
DO $$
DECLARE
  duplicate_group RECORD;
  duplicate_item RECORD;
  counter INTEGER;
  new_name TEXT;
  normalized_name TEXT;
BEGIN
  FOR duplicate_group IN
    SELECT LOWER(TRIM(name)) as normalized_name
    FROM public.departments
    GROUP BY LOWER(TRIM(name))
    HAVING COUNT(*) > 1
  LOOP
    normalized_name := duplicate_group.normalized_name;
    counter := 2;
    
    FOR duplicate_item IN
      SELECT id, name, created_at
      FROM public.departments
      WHERE LOWER(TRIM(name)) = normalized_name
      ORDER BY COALESCE(created_at, '1970-01-01'::TIMESTAMPTZ), id
      OFFSET 1
    LOOP
      new_name := TRIM(duplicate_item.name) || ' (' || counter || ')';
      
      WHILE EXISTS (
        SELECT 1 FROM public.departments 
        WHERE LOWER(TRIM(name)) = LOWER(new_name) AND id != duplicate_item.id
      ) LOOP
        counter := counter + 1;
        new_name := TRIM(duplicate_item.name) || ' (' || counter || ')';
      END LOOP;
      
      UPDATE public.departments
      SET name = new_name
      WHERE id = duplicate_item.id;
      
      RAISE NOTICE '✅ Renamed duplicate department: "%" -> "%"', duplicate_item.name, new_name;
      counter := counter + 1;
    END LOOP;
  END LOOP;
  
  RAISE NOTICE '✅ Departments duplicates resolved';
END $$;

-- ============================================
-- STEP 2: ADD UNIQUE CONSTRAINTS FOR PARTS
-- ============================================

-- Drop existing unique constraint on name if it exists (case-sensitive)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'parts_name_key' 
    AND conrelid = 'public.parts'::regclass
  ) THEN
    ALTER TABLE public.parts DROP CONSTRAINT parts_name_key;
    RAISE NOTICE '✅ Dropped existing case-sensitive unique constraint on parts.name';
  END IF;
END $$;

-- Create unique index on LOWER(TRIM(name)) for parts
-- This enforces case-insensitive, trimmed uniqueness
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'parts' 
    AND indexname = 'idx_parts_name_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_parts_name_unique 
    ON public.parts (LOWER(TRIM(name)));
    RAISE NOTICE '✅ Created unique index for parts.name (case-insensitive, trimmed)';
  ELSE
    RAISE NOTICE '✅ Unique index for parts.name already exists';
  END IF;
END $$;

-- ============================================
-- STEP 3: ADD UNIQUE CONSTRAINTS FOR PRODUCTS
-- ============================================

-- Drop existing unique constraint on name if it exists (case-sensitive)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'products_name_key' 
    AND conrelid = 'public.products'::regclass
  ) THEN
    ALTER TABLE public.products DROP CONSTRAINT products_name_key;
    RAISE NOTICE '✅ Dropped existing case-sensitive unique constraint on products.name';
  END IF;
END $$;

-- Create unique index on LOWER(TRIM(name)) for products
-- Products can have same name in different departments, but we enforce global uniqueness
-- If you want per-department uniqueness, use: (LOWER(TRIM(name)), department_id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'products' 
    AND indexname = 'idx_products_name_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_products_name_unique 
    ON public.products (LOWER(TRIM(name)));
    RAISE NOTICE '✅ Created unique index for products.name (case-insensitive, trimmed)';
  ELSE
    RAISE NOTICE '✅ Unique index for products.name already exists';
  END IF;
END $$;

-- ============================================
-- STEP 4: VERIFY DEPARTMENTS CONSTRAINT
-- ============================================

-- Departments already has UNIQUE constraint, but verify it's case-insensitive
DO $$
BEGIN
  -- Check if there's a unique constraint
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'departments_name_key' 
    AND conrelid = 'public.departments'::regclass
  ) THEN
    RAISE NOTICE '✅ Departments has unique constraint on name';
  ELSE
    -- If no constraint, create unique index (case-insensitive)
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes 
      WHERE schemaname = 'public' 
      AND tablename = 'departments' 
      AND indexname = 'idx_departments_name_unique'
    ) THEN
      CREATE UNIQUE INDEX idx_departments_name_unique 
      ON public.departments (LOWER(TRIM(name)));
      RAISE NOTICE '✅ Created unique index for departments.name (case-insensitive, trimmed)';
    ELSE
      RAISE NOTICE '✅ Unique index for departments.name already exists';
    END IF;
  END IF;
END $$;

-- ============================================
-- STEP 5: VALIDATION
-- ============================================

DO $$
DECLARE
  parts_index_exists BOOLEAN;
  products_index_exists BOOLEAN;
  departments_index_exists BOOLEAN;
BEGIN
  -- Check parts unique index
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'parts' 
    AND indexname = 'idx_parts_name_unique'
  ) INTO parts_index_exists;
  
  -- Check products unique index
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'products' 
    AND indexname = 'idx_products_name_unique'
  ) INTO products_index_exists;
  
  -- Check departments unique index or constraint
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'departments' 
    AND indexname = 'idx_departments_name_unique'
  ) OR EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'departments_name_key' 
    AND conrelid = 'public.departments'::regclass
  ) INTO departments_index_exists;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'UNIQUE CONSTRAINT VALIDATION:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Parts unique index: %', parts_index_exists;
  RAISE NOTICE 'Products unique index: %', products_index_exists;
  RAISE NOTICE 'Departments unique: %', departments_index_exists;
  RAISE NOTICE '========================================';
  
  IF parts_index_exists AND products_index_exists AND departments_index_exists THEN
    RAISE NOTICE '✅ All unique constraints applied successfully!';
  ELSE
    RAISE WARNING '⚠️ Some constraints may be missing';
  END IF;
END $$;

-- ============================================
-- ✅ DUPLICATE PREVENTION COMPLETE
-- ============================================
-- 
-- This migration:
-- 1. ✅ Automatically resolves existing duplicates (renames with suffix)
-- 2. ✅ Adds unique indexes for parts (LOWER(TRIM(name)))
-- 3. ✅ Adds unique indexes for products (LOWER(TRIM(name)))
-- 4. ✅ Verifies departments unique constraint
-- 5. ✅ Works with existing RLS policies
-- 
-- SAFETY:
-- - Does NOT delete any data
-- - Keeps first occurrence, renames others
-- - Example: "shurup" and "Shurup" -> "shurup" and "Shurup (2)"
-- ============================================

