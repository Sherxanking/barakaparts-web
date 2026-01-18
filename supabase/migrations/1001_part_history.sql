-- Part History Table
-- WHY: Track who added/updated parts and when
-- Supports: Audit trail for part quantity changes

CREATE TABLE IF NOT EXISTS part_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  part_id UUID NOT NULL REFERENCES parts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  action_type TEXT NOT NULL CHECK (action_type IN ('add', 'update', 'delete', 'create')),
  quantity_before INT DEFAULT 0,
  quantity_after INT DEFAULT 0,
  quantity_change INT NOT NULL, -- Positive for add, negative for remove
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_part_history_part_id ON part_history(part_id);
CREATE INDEX IF NOT EXISTS idx_part_history_user_id ON part_history(user_id);
CREATE INDEX IF NOT EXISTS idx_part_history_created_at ON part_history(created_at DESC);

-- RLS
ALTER TABLE part_history ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can read part history (for transparency)
DROP POLICY IF EXISTS "Anyone can read part history" ON part_history;
CREATE POLICY "Anyone can read part history" ON part_history
  FOR SELECT USING (true);

-- Policy: Authenticated users can create history entries
DROP POLICY IF EXISTS "Authenticated users can create history" ON part_history;
CREATE POLICY "Authenticated users can create history" ON part_history
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE part_history;

















