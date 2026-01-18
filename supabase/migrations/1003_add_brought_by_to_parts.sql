-- Add brought_by column to parts table
-- WHY: Track who brought each part

ALTER TABLE parts 
ADD COLUMN IF NOT EXISTS brought_by TEXT;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_parts_brought_by ON parts(brought_by);

-- Add comment
COMMENT ON COLUMN parts.brought_by IS 'Kim olib kelgan (masalan: Ahmad, Boss, va hokazo)';

















