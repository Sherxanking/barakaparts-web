-- ============================================
-- QUICK FIX: updated_at Column Error
-- ============================================
-- 
-- MUAMMO: "column updated_at of relation users does not exist"
-- 
-- YECHIM: updated_at column'ni yaratish
-- ============================================

-- Updated_at column'ni yaratish
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Tekshirish
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'updated_at'
  ) THEN
    RAISE NOTICE '✅ Updated_at column mavjud';
  ELSE
    RAISE EXCEPTION '❌ Updated_at column yaratilmadi!';
  END IF;
END $$;

-- ============================================
-- ENDI: 017_COMPLETE_FIX_ALL_USER_ISSUES.sql ni qayta bajarishingiz mumkin
-- ============================================















