-- ============================================
-- Enable Realtime for Parts Table
-- ============================================
-- WHY: Parts must be visible to all authenticated users in real-time
-- This migration enables realtime subscriptions for the parts table

-- Enable realtime publication for parts table
-- This allows Flutter app to receive real-time updates when parts are inserted/updated/deleted
ALTER PUBLICATION supabase_realtime ADD TABLE IF NOT EXISTS parts;

-- Verify RLS policy exists for SELECT (all authenticated users can read)
-- This policy should already exist from previous migrations, but we verify it here
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'parts' 
    AND policyname = 'Authenticated users can read parts'
  ) THEN
    -- Create the policy if it doesn't exist
    CREATE POLICY "Authenticated users can read parts" ON parts
      FOR SELECT USING (auth.role() = 'authenticated');
    RAISE NOTICE 'Created SELECT policy for parts table';
  ELSE
    RAISE NOTICE 'SELECT policy for parts table already exists';
  END IF;
END $$;

