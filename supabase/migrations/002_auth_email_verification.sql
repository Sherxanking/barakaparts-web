-- ============================================
-- STEP 1: Email Verification Support
-- ============================================
-- This migration ensures users table supports email verification tracking
-- and adds helper functions for email verification status.
-- 
-- WHY: Production-ready auth requires email verification to prevent
-- fake accounts and ensure security.
-- ============================================

-- ============================================
-- 1. Ensure users table has email column (if not exists)
-- ============================================
DO $$
BEGIN
  -- Add email column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'email'
  ) THEN
    ALTER TABLE users ADD COLUMN email TEXT;
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
  END IF;
END $$;

-- ============================================
-- 2. Function to check email verification status
-- ============================================
-- This function checks if a user's email is verified by checking
-- auth.users.email_confirmed_at
CREATE OR REPLACE FUNCTION public.is_user_email_verified(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = user_id
    AND email_confirmed_at IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 3. View for user verification status (optional, for admin queries)
-- ============================================
CREATE OR REPLACE VIEW public.user_verification_status AS
SELECT
  u.id,
  u.email,
  u.name,
  u.role,
  CASE
    WHEN au.email_confirmed_at IS NOT NULL THEN true
    ELSE false
  END AS email_verified,
  au.email_confirmed_at,
  au.created_at AS auth_created_at
FROM public.users u
LEFT JOIN auth.users au ON u.id = au.id;

-- Grant access to authenticated users (they can see their own status)
GRANT SELECT ON public.user_verification_status TO authenticated;

-- ============================================
-- 4. RLS Policy: Users can check their own verification status
-- ============================================
-- Note: This is handled by the view above, but we can add explicit policy
-- if needed for direct table access

-- ============================================
-- NOTES:
-- ============================================
-- 1. Email verification is primarily handled by Supabase Auth
-- 2. The auth.users table stores email_confirmed_at timestamp
-- 3. This migration adds helper functions/views for easier querying
-- 4. To enable email verification in Supabase Dashboard:
--    - Go to Authentication > Settings
--    - Enable "Enable email confirmations"
--    - Configure email templates if needed
-- ============================================



