-- Migration: Set boss role for specific user
-- Date: 2024
-- Description: Sets boss role for a user by email
-- 
-- INSTRUCTIONS:
-- 1. Replace 'your-email@example.com' with the actual email address
-- 2. Run this migration in Supabase SQL Editor
-- 3. User will have boss role after next login

-- ============================================
-- STEP 1: Set boss role for specific email
-- ============================================
-- Replace 'your-email@example.com' with your actual email
UPDATE public.users 
SET role = 'boss', updated_at = NOW()
WHERE LOWER(email) = LOWER('your-email@example.com');

-- ============================================
-- STEP 2: Also update auth.users metadata
-- ============================================
-- This ensures role is set in auth metadata as well
UPDATE auth.users
SET raw_user_meta_data = jsonb_set(
  COALESCE(raw_user_meta_data, '{}'::jsonb),
  '{role}',
  '"boss"'
)
WHERE LOWER(email) = LOWER('your-email@example.com');

-- ============================================
-- STEP 3: Verify the update
-- ============================================
SELECT 
  u.id,
  u.name,
  u.email,
  u.role,
  u.created_at,
  au.raw_user_meta_data->>'role' as auth_role
FROM public.users u
LEFT JOIN auth.users au ON u.id = au.id
WHERE LOWER(u.email) = LOWER('your-email@example.com');

-- ============================================
-- ALTERNATIVE: Set boss role for multiple emails
-- ============================================
-- UPDATE public.users 
-- SET role = 'boss', updated_at = NOW()
-- WHERE LOWER(email) IN (
--   LOWER('email1@example.com'),
--   LOWER('email2@example.com')
-- );

-- ============================================
-- NOTE:
-- ============================================
-- After updating, user needs to logout and login again 
-- for role to take effect in the app.

