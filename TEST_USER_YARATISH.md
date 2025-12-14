# 👤 Test User Yaratish - Qadamma-Qadam

## ⚠️ MUHIM: 2 Qadam Kerak!

Test user yaratish uchun **2 qadam** kerak:
1. **Authentication** da user yaratish (Supabase Dashboard)
2. **Users jadvaliga** qo'shish (SQL Editor)

## 📋 Qadamma-Qadam

### Qadam 1: Authentication da User Yaratish

1. **Supabase Dashboard** ga kiring
2. Chap menudan **Authentication** → **Users** ga kiring
3. **Add user** tugmasini bosing
4. Quyidagilarni kiriting:
   - **Email**: `boss@test.com`
   - **Password**: `test123` (yoki boshqa parol)
   - **Auto Confirm User**: ✅ (checkbox belgilang)
5. **Create user** tugmasini bosing
6. **User ID ni ko'chirib oling** (masalan: `abc123-def456-...`)

### Qadam 2: Users Jadvaliga Qo'shish

1. **SQL Editor** ga kiring
2. Quyidagi SQL ni yozing (USER_ID ni o'zgartiring!):

```sql
-- USER_ID ni Qadam 1 dan oling!
INSERT INTO users (id, name, email, role) VALUES
  ('USER_ID_BU_YERGA', 'Test Boss', 'boss@test.com', 'boss')
ON CONFLICT (id) DO UPDATE SET role = 'boss';
```

**Misol:**
```sql
INSERT INTO users (id, name, email, role) VALUES
  ('544b3d60-3d7a-440d-8b12-e9fabee1901a', 'Test Boss', 'boss@test.com', 'boss')
ON CONFLICT (id) DO UPDATE SET role = 'boss';
```

3. **Run** tugmasini bosing
4. "Success" xabari chiqishi kerak

### Qadam 3: Tekshirish

1. **Table Editor** → **users** jadvalini oching
2. Yaratilgan user ko'rinishi kerak
3. **role** ustuni `boss` bo'lishi kerak

### Qadam 4: App da Login

1. App ni ishga tushiring
2. LoginPage ochiladi
3. **Email**: `boss@test.com`
4. **Password**: `test123`
5. **Login** tugmasini bosing

## ⚠️ Eslatmalar

1. **ID bir xil bo'lishi kerak**:
   - Authentication user ID = Users jadvalidagi ID
   - Agar boshqacha bo'lsa, login ishlamaydi

2. **Email bir xil bo'lishi kerak**:
   - Authentication email = Users jadvalidagi email

3. **Auto Confirm**:
   - Authentication da "Auto Confirm User" checkbox belgilang
   - Aks holda email tasdiqlash kerak bo'ladi

## 🔍 Muammo Bo'lsa

Agar login ishlamasa:
1. Console da xatolik xabari qanday?
2. User ID bir xil ekanligini tekshiring
3. Email bir xil ekanligini tekshiring
4. Users jadvalida user borligini tekshiring




