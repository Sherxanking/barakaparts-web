-- ============================================
-- XAVFSIZ SQL QUERY - Yangi User Qo'shish
-- ============================================
-- Bu query faqat user qo'shadi, hech narsani o'chirmaydi
-- ============================================

-- Variant 1: Agar user mavjud bo'lmasa, qo'shadi
-- Agar mavjud bo'lsa, hech narsa qilmaydi (xavfsiz)
INSERT INTO users (id, name, email, role) VALUES
  ('cfb969d9-266c-4ca5-bd90-2f4c508d08e3', 'Boss User', 'asosiy@test.com', 'boss')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- Variant 2: Agar user mavjud bo'lsa, yangilaydi
-- (Bu variant xavfsiz, lekin mavjud ma'lumotlarni o'zgartiradi)
-- ============================================
-- INSERT INTO users (id, name, email, role) VALUES
--   ('cfb969d9-266c-4ca5-bd90-2f4c508d08e3', 'Boss User', 'asosiy@test.com', 'boss')
-- ON CONFLICT (id) DO UPDATE SET 
--   name = EXCLUDED.name,
--   email = EXCLUDED.email,
--   role = EXCLUDED.role;

-- ============================================
-- Variant 3: Avval tekshirish, keyin qo'shish
-- (Eng xavfsiz variant)
-- ============================================
-- Avval tekshirish:
-- SELECT * FROM users WHERE id = 'cfb969d9-266c-4ca5-bd90-2f4c508d08e3';

-- Agar topilmasa, keyin qo'shish:
-- INSERT INTO users (id, name, email, role) VALUES
--   ('cfb969d9-266c-4ca5-bd90-2f4c508d08e3', 'Boss User', 'asosiy@test.com', 'boss');




