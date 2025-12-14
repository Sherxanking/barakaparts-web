-- ============================================
-- BarakaParts uchun Test Akkauntlar Yaratish
-- ============================================
-- NIMA UCHUN: Test rejimi sozlash - Manager va Boss test akkauntlarini yaratish
-- Bu akkauntlar Google OAuth ni o'tkazib yuboradi va email/password login ishlatadi

-- ============================================
-- 1. AUTH.USERS DA TEST AKKAUNTLAR YARATISH
-- ============================================
-- Eslatma: Bu akkauntlar Supabase Dashboard → Authentication → Users orqali yaratilishi kerak
-- Yoki Supabase Auth API orqali. Bu SQL faqat ma'lumot uchun.
-- 
-- Manager Akkaunti:
-- Email: manager@test.com
-- Parol: Manager123!
-- Role: manager
--
-- Boss Akkaunti:
-- Email: boss@test.com
-- Parol: Boss123!
-- Role: boss

-- ============================================
-- 2. PUBLIC.USERS DA FOYDALANUVCHI PROFILLARINI YARATISH
-- ============================================
-- Bu avtomatik ravishda trigger handle_new_user() tomonidan amalga oshiriladi
-- Lekin kerak bo'lsa, qo'lda ham yaratish mumkin:

-- Avval, akkauntlar yaratilgandan keyin auth.users dan user ID larni oling:
-- SELECT id, email FROM auth.users WHERE email IN ('manager@test.com', 'boss@test.com');

-- Keyin public.users ga qo'shing (USER_ID_MANAGER va USER_ID_BOSS ni haqiqiy ID lar bilan almashtiring):
/*
INSERT INTO public.users (id, name, email, role, created_at)
VALUES
  (
    'USER_ID_MANAGER',  -- auth.users dan haqiqiy manager user ID bilan almashtiring
    'Test Manager',
    'manager@test.com',
    'manager',
    NOW()
  ),
  (
    'USER_ID_BOSS',  -- auth.users dan haqiqiy boss user ID bilan almashtiring
    'Test Boss',
    'boss@test.com',
    'boss',
    NOW()
  )
ON CONFLICT (id) DO UPDATE
SET
  role = EXCLUDED.role,
  name = EXCLUDED.name,
  email = EXCLUDED.email;
*/

-- ============================================
-- 3. TEST AKKAUNTLARNI TEKSHIRISH
-- ============================================
-- Akkauntlar yaratilgandan keyin, ular mavjudligini tekshiring:
/*
SELECT 
  u.id,
  u.email,
  u.name,
  u.role,
  u.created_at
FROM public.users u
WHERE u.email IN ('manager@test.com', 'boss@test.com');
*/

-- ============================================
-- 4. QO'LDA AKKAUNT YARATISH (kerak bo'lsa)
-- ============================================
-- Agar Supabase Dashboard orqali qo'lda akkauntlar yaratish kerak bo'lsa:
--
-- Qadam 1: Supabase Dashboard → Authentication → Users ga o'ting
-- Qadam 2: "Add User" → "Create new user" ni bosing
-- Qadam 3: Manager uchun:
--   - Email: manager@test.com
--   - Parol: Manager123!
--   - Auto Confirm User: ON
-- Qadam 4: Boss uchun:
--   - Email: boss@test.com
--   - Parol: Boss123!
--   - Auto Confirm User: ON
-- Qadam 5: Trigger handle_new_user() avtomatik ravishda public.users da profillarni yaratadi
-- Qadam 6: Kerak bo'lsa, rollarni qo'lda yangilang:
/*
UPDATE public.users
SET role = 'manager'
WHERE email = 'manager@test.com';

UPDATE public.users
SET role = 'boss'
WHERE email = 'boss@test.com';
*/

-- ============================================
-- XULOSA
-- ============================================
-- ✅ Manager akkaunti: manager@test.com / Manager123! → role 'manager'
-- ✅ Boss akkaunti: boss@test.com / Boss123! → role 'boss'
-- ✅ Google OAuth foydalanuvchilar → role 'worker' (default)
-- ✅ Barcha akkauntlar public.users jadvalida saqlanadi
-- ✅ Ma'lumotlar saqlanishi Supabase SQL jadvallarida tekshirildi
