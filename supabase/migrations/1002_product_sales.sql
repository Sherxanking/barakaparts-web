-- Product Sales History Table
-- WHY: Track which products were sold to which departments
-- Supports: Audit trail for product sales

CREATE TABLE IF NOT EXISTS product_sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  department_id UUID NOT NULL REFERENCES departments(id),
  department_name TEXT NOT NULL,
  quantity INT NOT NULL,
  order_id UUID REFERENCES orders(id),
  sold_by UUID REFERENCES users(id), -- Kim complete qilgan
  sold_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_product_sales_product_id ON product_sales(product_id);
CREATE INDEX IF NOT EXISTS idx_product_sales_department_id ON product_sales(department_id);
CREATE INDEX IF NOT EXISTS idx_product_sales_sold_at ON product_sales(sold_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_sales_order_id ON product_sales(order_id);

-- RLS
ALTER TABLE product_sales ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can read sales history (for transparency)
DROP POLICY IF EXISTS "Anyone can read sales history" ON product_sales;
CREATE POLICY "Anyone can read sales history" ON product_sales
  FOR SELECT USING (true);

-- Policy: Authenticated users can create sales entries
DROP POLICY IF EXISTS "Authenticated users can create sales" ON product_sales;
CREATE POLICY "Authenticated users can create sales" ON product_sales
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE product_sales;

















