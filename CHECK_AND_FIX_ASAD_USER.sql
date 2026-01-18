-- ============================================
-- CHECK AND FIX ASAD USER (asad123@gmail.com)
-- ============================================
-- Bu SQL query asad123@gmail.com user'ni tekshiradi va kerak bo'lsa yaratadi
-- Supabase Dashboard → SQL Editor da RUN qiling

-- STEP 1: Auth users'da tekshirish
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  raw_user_meta_data->>'name' as name,
  raw_user_meta_data->>'role' as role
FROM auth.users
WHERE email = 'asad123@gmail.com';

-- STEP 2: Public users jadvalida tekshirish
SELECT 
  id,
  name,
  email,
  role,
  created_at
FROM public.users
WHERE email = 'asad123@gmail.com';

-- STEP 3: Agar auth.users'da user bor, lekin public.users'da yo'q bo'lsa, yaratish
-- FIX: Auth user mavjud, lekin public.users'da profili yo'q
DO $$
DECLARE
  auth_user_id UUID;
  auth_user_email TEXT;
  auth_user_name TEXT;
  auth_user_role TEXT;
BEGIN
  -- Auth users'da user'ni topish
  SELECT 
    id,
    email,
    COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1)),
    COALESCE(raw_user_meta_data->>'role', 'worker')
  INTO auth_user_id, auth_user_email, auth_user_name, auth_user_role
  FROM auth.users
  WHERE email = 'asad123@gmail.com'
  LIMIT 1;

  -- Agar auth user topilsa va public.users'da yo'q bo'lsa, yaratish
  IF auth_user_id IS NOT NULL THEN
    -- Public users'da tekshirish
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = auth_user_id) THEN
      -- Public users'da yaratish
      INSERT INTO public.users (id, name, email, role, created_at)
      VALUES (
        auth_user_id,
        auth_user_name,
        auth_user_email,
        auth_user_role,
        NOW()
      )
      ON CONFLICT (id) DO UPDATE
      SET 
        name = EXCLUDED.name,
        email = EXCLUDED.email,
        role = EXCLUDED.role;
      
      RAISE NOTICE '✅ User profile yaratildi: % (%, %)', auth_user_name, auth_user_email, auth_user_role;
    ELSE
      RAISE NOTICE 'ℹ️ User profile allaqachon mavjud: %', auth_user_email;
    END IF;
  ELSE
    RAISE NOTICE '⚠️ Auth users''da asad123@gmail.com topilmadi. Avval ro''yxatdan o''ting.';
  END IF;
END $$;

-- STEP 4: Natijani tekshirish
SELECT 
  u.id,
  u.name,
  u.email,
  u.role,
  u.created_at,
  CASE 
    WHEN au.id IS NOT NULL THEN '✅ Auth user mavjud'
    ELSE '❌ Auth user yo''q'
  END as auth_status,
  CASE 
    WHEN u.id IS NOT NULL THEN '✅ Public user mavjud'
    ELSE '❌ Public user yo''q'
  END as public_status
FROM public.users u
FULL OUTER JOIN auth.users au ON u.id = au.id
WHERE COALESCE(u.email, au.email) = 'asad123@gmail.com';

-- ============================================
-- AGAR USER YO'Q BO'LSA, RO'YXATDAN O'TISH KERAK
-- ============================================
-- Agar yuqoridagi query'lar user'ni topmasa, app orqali ro'yxatdan o'ting:
-- 1. Login sahifasida "Sign Up" tugmasini bosing
-- 2. Email: asad123@gmail.com
-- 3. Parol kiriting
-- 4. Ism kiriting
-- 5. Ro'yxatdan o'ting



