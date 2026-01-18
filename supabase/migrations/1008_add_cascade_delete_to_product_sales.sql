-- Migration: Add CASCADE DELETE to product_sales.order_id
-- Date: 2024
-- Description: When an order is deleted, automatically delete related product_sales entries

-- Drop existing foreign key constraint
ALTER TABLE product_sales
DROP CONSTRAINT IF EXISTS product_sales_order_id_fkey;

-- Recreate foreign key with CASCADE DELETE
ALTER TABLE product_sales
ADD CONSTRAINT product_sales_order_id_fkey
FOREIGN KEY (order_id)
REFERENCES orders(id)
ON DELETE CASCADE;

-- Verify constraint was created
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_schema = 'public' 
    AND table_name = 'product_sales' 
    AND constraint_name = 'product_sales_order_id_fkey'
  ) THEN
    RAISE NOTICE '✅ CASCADE DELETE constraint added successfully';
  ELSE
    RAISE EXCEPTION '❌ Failed to add CASCADE DELETE constraint';
  END IF;
END $$;
















