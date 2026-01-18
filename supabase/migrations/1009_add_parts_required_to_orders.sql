-- Migration: Add parts_required column to orders table
-- Date: 2024
-- Description: Store snapshot of parts required when order is created
-- This ensures that when order is deleted, we restore the correct part quantities
-- even if the product's parts have been modified since order creation

-- Add parts_required column (JSONB to store Map<String, int>)
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS parts_required JSONB DEFAULT '{}';

-- Add comment
COMMENT ON COLUMN public.orders.parts_required IS 'Snapshot of parts required when order was created (part_id -> quantity_per_product)';

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_orders_parts_required ON public.orders USING GIN (parts_required);

-- Verify column was added
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'orders' 
    AND column_name = 'parts_required'
  ) THEN
    RAISE NOTICE '✅ parts_required column added successfully';
  ELSE
    RAISE EXCEPTION '❌ Failed to add parts_required column';
  END IF;
END $$;
















