-- Add sold_to column to orders table
-- WHY: Track who the order was sold to

ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS sold_to TEXT;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_orders_sold_to ON orders(sold_to);

-- Add comment
COMMENT ON COLUMN orders.sold_to IS 'Kimga sotilgan (masalan: Ahmad, Mijoz nomi, va hokazo)';

















