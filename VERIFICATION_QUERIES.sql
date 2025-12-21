-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these AFTER the migration to verify results
-- ============================================

-- Query 1: Check auth.users for test accounts
SELECT id, email 
FROM auth.users 
WHERE email IN ('boss@test.com', 'manager@test.com');

-- Query 2: Check public.users for test accounts
SELECT id, email, role 
FROM public.users 
WHERE email IN ('boss@test.com', 'manager@test.com');

-- Query 3: Check trigger exists
SELECT tgname 
FROM pg_trigger 
WHERE tgrelid = 'auth.users'::regclass;

-- Query 4: Final counts
SELECT COUNT(*) as public_users_count FROM public.users;
SELECT COUNT(*) as auth_users_count FROM auth.users;














