-- ============================================
-- CREATE MISSING TEST USERS IN public.users
-- ============================================
-- Run this ONLY if test accounts exist in auth.users but not in public.users
-- ============================================
-- 
-- STEP 1: First, get the IDs from auth.users:
-- 
-- SELECT id, email 
-- FROM auth.users 
-- WHERE email IN ('boss@test.com', 'manager@test.com');
--
-- STEP 2: Replace <BOSS_ID> and <MANAGER_ID> below with actual IDs from step 1
-- ============================================

-- For boss@test.com
INSERT INTO public.users (id, name, email, role, created_at)
VALUES ('48ac9358-b302-4b01-9706-0c1600497a1c', 'Boss', 'boss@test.com', 'boss', NOW())
ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;

-- For manager@test.com
INSERT INTO public.users (id, name, email, role, created_at)
VALUES ('2f1c663b-a846-4f60-a3b4-1848a15760e6', 'Manager', 'manager@test.com', 'manager', NOW())
ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;

