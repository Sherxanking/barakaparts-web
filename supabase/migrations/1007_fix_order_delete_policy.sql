-- Migration: Fix Order Delete Policy for Boss
-- Date: 2024
-- Description: Ensures boss role can delete completed orders

-- Drop existing delete policy
DROP POLICY IF EXISTS "orders_delete" ON public.orders;

-- Create new policy: Manager and Boss can delete orders (including completed)
CREATE POLICY "orders_delete"
ON public.orders
FOR DELETE
USING (
  public.get_user_role(auth.uid()) IN ('manager', 'boss')
);

-- Verify policy was created
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'orders' 
    AND policyname = 'orders_delete'
  ) THEN
    RAISE NOTICE '✅ Order delete policy updated successfully';
  ELSE
    RAISE EXCEPTION '❌ Failed to create order delete policy';
  END IF;
END $$;
















