-- ============================================
-- Migration: Worker can complete pending orders
-- ============================================
-- 
-- GOAL: Allow workers to complete orders directly from pending status
-- without requiring in_progress transition
-- ============================================

-- Drop existing policy
DROP POLICY IF EXISTS "orders_update" ON public.orders;

-- Create new policy that allows workers to complete their own orders
CREATE POLICY "orders_update"
ON public.orders
FOR UPDATE
USING (
  auth.role() = 'authenticated' AND (
    -- Manager and Boss can update any order
    public.get_user_role(auth.uid()) IN ('manager', 'boss') OR
    -- Worker can complete their own orders (pending or in_progress)
    (
      public.get_user_role(auth.uid()) = 'worker' AND
      worker_id = auth.uid() AND
      status IN ('pending', 'in_progress', 'partially_completed')
    )
  )
);

-- Verification query
DO $$
DECLARE
  policy_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'orders' AND policyname = 'orders_update'
  ) INTO policy_exists;
  
  IF policy_exists THEN
    RAISE NOTICE '✅ Worker order completion policy created successfully';
  ELSE
    RAISE WARNING '⚠️ Policy creation failed';
  END IF;
END $$;
