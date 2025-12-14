# 👥 Rollar Tizimi - Qo'llanma

## 📋 Rollar

App da 4 ta rol mavjud:

1. **worker** - Ishchi
   - Qismlar qo'shishi mumkin (o'zi yaratgan)
   - Buyurtma yaratishi mumkin
   - O'z loglarini ko'ra oladi
   - ❌ O'chirish huquqi yo'q

2. **manager** - Menejer
   - Qismlar va mahsulotlarni tahrirlashi mumkin
   - Buyurtmalarni tasdiqlash/rad etish
   - Barcha loglarni ko'ra oladi
   - ❌ Foydalanuvchilarni o'chirish huquqi yo'q

3. **boss** - Boshliq
   - ✅ To'liq huquq (barcha operatsiyalar)
   - Foydalanuvchilarni boshqarish
   - Analytics ko'rish
   - Barcha loglarni ko'rish

4. **supplier** - Ta'minotchi
   - Katta partiyalar qo'shish
   - Qismlarni yangilash
   - ❌ Ichki loglarni ko'ra olmaydi

## 🔐 Rollarni Qanday Beraman?

### Variant 1: Supabase Dashboard orqali (Test uchun)

1. **Supabase Dashboard** ga kiring
2. **Authentication** → **Users** ga kiring
3. **Add user** tugmasini bosing
4. Email va Password kiriting
5. User yaratilgandan keyin, **SQL Editor** ga kiring va quyidagini bajaring:

```sql
-- User ID ni oling (Authentication → Users dan)
-- Masalan: user_id = '123e4567-e89b-12d3-a456-426614174000'

-- Users jadvaliga qo'shing
INSERT INTO users (id, name, email, role) VALUES
  ('123e4567-e89b-12d3-a456-426614174000', 'Boss User', 'boss@example.com', 'boss');
```

### Variant 2: App ichida Register (Keyinroq)

App ichida Register sahifasi qo'shiladi, lekin hozircha yo'q.

### Variant 3: SQL orqali To'g'ridan-to'g'ri

```sql
-- 1. Avval Authentication orqali user yaratish kerak
-- 2. Keyin users jadvaliga qo'shish:

INSERT INTO users (id, name, email, role) VALUES
  (gen_random_uuid(), 'Boss User', 'boss@example.com', 'boss'),
  (gen_random_uuid(), 'Manager User', 'manager@example.com', 'manager'),
  (gen_random_uuid(), 'Worker User', 'worker@example.com', 'worker');
```

⚠️ **MUHIM**: `id` Authentication user ID bilan bir xil bo'lishi kerak!

## 🚀 Tezkor Test Qilish

### 1. Supabase da Test User Yaratish

1. **Supabase Dashboard** → **Authentication** → **Users**
2. **Add user** → Email: `boss@test.com`, Password: `test123`
3. User ID ni ko'chirib oling (masalan: `abc123...`)

### 2. Users Jadvaliga Qo'shish

**SQL Editor** ga quyidagini bajaring:

```sql
-- User ID ni o'zgartiring!
INSERT INTO users (id, name, email, role) VALUES
  ('USER_ID_BU_YERGA', 'Test Boss', 'boss@test.com', 'boss')
ON CONFLICT (id) DO UPDATE SET role = 'boss';
```

### 3. App da Login Qilish

1. App ni ishga tushiring
2. LoginPage ochiladi
3. Email: `boss@test.com`
4. Password: `test123`
5. Login tugmasini bosing

## 📊 Rollar va Huquqlar Jadvali

| Operatsiya | Worker | Manager | Boss | Supplier |
|------------|--------|---------|------|----------|
| Qism qo'shish | ✅ (o'zi) | ✅ | ✅ | ✅ |
| Qism tahrirlash | ❌ | ✅ | ✅ | ✅ |
| Qism o'chirish | ❌ | ❌ | ✅ | ❌ |
| Mahsulot tahrirlash | ❌ | ✅ | ✅ | ❌ |
| Buyurtma yaratish | ✅ | ✅ | ✅ | ✅ |
| Buyurtma tasdiqlash | ❌ | ✅ | ✅ | ❌ |
| Loglarni ko'rish | ✅ (o'zi) | ✅ (barcha) | ✅ (barcha) | ❌ |
| Foydalanuvchi boshqarish | ❌ | ❌ | ✅ | ❌ |
| Analytics | ❌ | ✅ | ✅ | ❌ |

## ⚠️ Eslatmalar

1. **Authentication va Users jadvali alohida**
   - Authentication → Supabase Auth (email/password)
   - Users jadvali → Role va boshqa ma'lumotlar

2. **ID bir xil bo'lishi kerak**
   - Authentication user ID = Users jadvalidagi ID

3. **Rollarni o'zgartirish**
   ```sql
   UPDATE users SET role = 'manager' WHERE email = 'user@example.com';
   ```

## 🎯 Keyingi Qadamlar

1. ✅ Login sahifasi yaratildi
2. ⏭️ Register sahifasi yaratish
3. ⏭️ User management sahifasi (Boss uchun)
4. ⏭️ Role-based UI (huquqlarga qarab ko'rsatish)




