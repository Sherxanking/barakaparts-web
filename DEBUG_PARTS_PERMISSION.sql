-- ============================================
-- DEBUG: Parts Yaratish Permission Muammosini Tekshirish
-- ============================================
-- 
-- Bu so'rovlar muammoni aniqlashga yordam beradi
-- ============================================

-- Query 1: Current user'ning role'ini tekshirish
SELECT 
  id,
  email,
  role,
  created_at
FROM public.users
WHERE id = auth.uid();

-- Query 2: Parts table uchun RLS policies'ni tekshirish
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'parts' 
AND schemaname = 'public'
ORDER BY cmd, policyname;

-- Query 3: RLS yoqilganligini tekshirish
SELECT 
  relname,
  relrowsecurity as rls_enabled
FROM pg_class
WHERE relname = 'parts' 
AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Query 4: Parts table structure
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'parts'
ORDER BY ordinal_position;

-- Query 5: Test - Parts yaratishga urinish (agar xato bo'lsa, ko'rsatadi)
-- NOTE: Bu so'rovni faqat tekshirish uchun ishlating
DO $$
DECLARE
  current_user_id UUID;
  current_user_role TEXT;
  can_insert BOOLEAN;
BEGIN
  -- Current user ID
  current_user_id := auth.uid();
  
  -- Current user role
  SELECT role INTO current_user_role
  FROM public.users
  WHERE id = current_user_id;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DEBUG INFO:';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Current User ID: %', current_user_id;
  RAISE NOTICE 'Current User Role: %', current_user_role;
  
  -- Can insert check
  can_insert := (
    current_user_role IN ('manager', 'boss')
  );
  
  IF can_insert THEN
    RAISE NOTICE '✅ User CAN create parts (role: %)', current_user_role;
  ELSE
    RAISE NOTICE '❌ User CANNOT create parts (role: %)', current_user_role;
    RAISE NOTICE '⚠️ Required role: manager or boss';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;








