-- ============================================
-- Migration 1009: Fix RLS recursion on public.users
-- ============================================
--
-- PROBLEM:
-- RLS policies on public.users were querying public.users, causing
-- "infinite recursion detected in policy for relation users".
--
-- FIX:
-- Use SECURITY DEFINER helpers with row_security=off to read
-- current user's role/department without recursion.
-- ============================================

-- Helper: current user's role (bypasses RLS safely)
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$;

-- Helper: current user's department_id (optional)
-- Create a safe function even if department_id column doesn't exist
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'department_id'
  ) THEN
    EXECUTE $FN$
      CREATE OR REPLACE FUNCTION public.current_user_department_id()
      RETURNS UUID
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = public
      SET row_security = off
      AS $body$
        SELECT department_id FROM public.users WHERE id = auth.uid() LIMIT 1;
      $body$;
    $FN$;
  ELSE
    EXECUTE $FN$
      CREATE OR REPLACE FUNCTION public.current_user_department_id()
      RETURNS UUID
      LANGUAGE sql
      SECURITY DEFINER
      SET search_path = public
      SET row_security = off
      AS $body$
        SELECT NULL::uuid;
      $body$;
    $FN$;
  END IF;
END $$;

-- Recreate users policies without recursion
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Boss and manager can read all users" ON public.users;
DROP POLICY IF EXISTS "Manager can read department users" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Boss can update users" ON public.users;

CREATE POLICY "Users can read own data" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Boss and manager can read all users" ON public.users
  FOR SELECT USING (public.current_user_role() IN ('boss', 'manager'));

-- Create department-scoped policy only if department_id exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'department_id'
  ) THEN
    EXECUTE $POLICY$
      CREATE POLICY "Manager can read department users" ON public.users
        FOR SELECT USING (
          public.current_user_role() = 'manager'
          AND public.current_user_department_id() IS NOT NULL
          AND public.current_user_department_id() = public.users.department_id
        );
    $POLICY$;
  END IF;
END $$;

CREATE POLICY "Users can insert own data" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Boss can update users" ON public.users
  FOR UPDATE USING (public.current_user_role() = 'boss')
  WITH CHECK (public.current_user_role() = 'boss');

-- ============================================
-- ✅ DONE
-- ============================================
