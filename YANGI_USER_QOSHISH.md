# 👤 Yangi User Qo'shish - Qadamma-Qadam

## ❓ Nima Bo'ldi?

Logout qilib, qayta login qilganingizda **yangi user** yaratildi. Bu normal holat - har safar yangi email bilan login qilsangiz, yangi user yaratiladi.

## 📋 Qadamma-Qadam

### Qadam 1: Supabase Dashboard ga Kiring

1. [supabase.com](https://supabase.com) ga kiring
2. Project ni tanlang
3. Chap menudan **SQL Editor** ga kiring

### Qadam 2: SQL Query Yozing

SQL Editor da quyidagi SQL ni yozing:

```sql
INSERT INTO users (id, name, email, role) VALUES
  ('cfb969d9-266c-4ca5-bd90-2f4c508d08e3', 'Boss User', 'asosiy@test.com', 'boss')
ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  role = EXCLUDED.role;
```

**⚠️ MUHIM:**
- `id` - Bu sizning User ID (cfb969d9-266c-4ca5-bd90-2f4c508d08e3)
- `name` - User nomi (o'zingiz xohlagan nom)
- `email` - Login qilgan email (asosiy@test.com)
- `role` - Rol: `boss`, `manager`, `worker`, yoki `supplier`

### Qadam 3: SQL ni Bajarish

1. SQL Editor da query ni yozing
2. **Run** tugmasini bosing (yoki Ctrl+Enter)
3. "Success" xabari chiqishi kerak

### Qadam 4: App da Qayta Login

1. App ga qayting
2. **Login** tugmasini bosing
3. Email: `asosiy@test.com`
4. Password ni kiriting
5. Endi muvaffaqiyatli bo'lishi kerak!

## 🔍 Nima Sabab?

Har safar **yangi email** bilan login qilsangiz, Supabase Authentication da **yangi user** yaratiladi. Lekin `users` jadvalida hali yo'q, shuning uchun SQL orqali qo'shish kerak.

## 💡 Yaxshiroq Yechim (Keyinroq)

Keyinroq **auto-create** funksiyasini qo'shamiz - login qilganda avtomatik users jadvaliga qo'shiladi.

## ⚠️ Eslatmalar

1. **Har safar yangi email = yangi user**
2. **Users jadvaliga qo'shish kerak**
3. **ID bir xil bo'lishi kerak** (Authentication ID = Users ID)

---

**SQL ni bajaring va qayta login qiling!**




