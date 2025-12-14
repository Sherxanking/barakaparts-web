# 👤 User Jadvaliga Qo'shish - Qadamma-Qadam

## ✅ Login Muvaffaqiyatli!

Login qildingiz, lekin user ma'lumotlari `users` jadvalida topilmadi. Endi qo'shish kerak.

## 📋 Qadamma-Qadam

### Qadam 1: Supabase Dashboard ga Kiring

1. [supabase.com](https://supabase.com) ga kiring
2. Project ni tanlang
3. Chap menudan **SQL Editor** ga kiring

### Qadam 2: SQL Query Yozing

SQL Editor da quyidagi SQL ni yozing:

```sql
INSERT INTO users (id, name, email, role) VALUES
  ('ec4e70b3-3a71-4fbc-bcc6-4ba09e4ba6f8', 'Test Boss', 'boss@test.com', 'boss')
ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  role = EXCLUDED.role;
```

**⚠️ MUHIM:**
- `id` - Bu sizning User ID (ec4e70b3-3a71-4fbc-bcc6-4ba09e4ba6f8)
- `name` - User nomi (o'zingiz xohlagan nom)
- `email` - Login qilgan email
- `role` - Rol: `boss`, `manager`, `worker`, yoki `supplier`

### Qadam 3: SQL ni Bajarish

1. SQL Editor da query ni yozing
2. **Run** tugmasini bosing (yoki Ctrl+Enter)
3. "Success" xabari chiqishi kerak

### Qadam 4: Tekshirish

1. Chap menudan **Table Editor** → **users** ga kiring
2. Yaratilgan user ko'rinishi kerak
3. `role` ustuni `boss` bo'lishi kerak

### Qadam 5: App da Qayta Login

1. App ga qayting
2. **Login** tugmasini bosing
3. Email va Password kiriting
4. Endi muvaffaqiyatli bo'lishi kerak!

## 🎯 Misol SQL

Agar email `boss@test.com` bo'lsa:

```sql
INSERT INTO users (id, name, email, role) VALUES
  ('ec4e70b3-3a71-4fbc-bcc6-4ba09e4ba6f8', 'Boss User', 'boss@test.com', 'boss')
ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  role = EXCLUDED.role;
```

Agar email boshqa bo'lsa, `boss@test.com` o'rniga o'sha email ni yozing.

## ⚠️ Eslatmalar

1. **ID bir xil bo'lishi kerak**
   - Authentication user ID = Users jadvalidagi ID
   - Bu ID o'zgarmaydi

2. **Email bir xil bo'lishi kerak**
   - Login qilgan email = Users jadvalidagi email

3. **Role tanlash**
   - `boss` - To'liq huquq
   - `manager` - Menejer huquqlari
   - `worker` - Ishchi huquqlari
   - `supplier` - Ta'minotchi huquqlari

## 🔍 Muammo Bo'lsa

Agar SQL bajarishda xatolik chiqsa:
1. Users jadvali yaratilganini tekshiring
2. SQL sintaksis to'g'riligini tekshiring
3. User ID to'g'riligini tekshiring

---

**SQL ni bajaring va qayta login qiling!**




