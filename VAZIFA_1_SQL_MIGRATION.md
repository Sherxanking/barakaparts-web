# 🎯 Vazifa 1: SQL Migration Bajarish

## 📋 Nima Qilish Kerak?

Supabase da SQL migration ni bajarish - bu RLS Policy lar va Trigger ni sozlash uchun.

## 🧭 Qadammalar:

### Qadam 1: Supabase Dashboard ga Kiring

1. [supabase.com](https://supabase.com) ga kiring
2. Project ni tanlang
3. Chap menudan **SQL Editor** ga kiring

### Qadam 2: SQL Faylni Ochish

1. `supabase/migrations/001_auth_and_users_FIXED.sql` faylini oching
2. Barcha SQL kodini copy qiling

### Qadam 3: SQL ni Bajarish

1. SQL Editor ga yozing
2. **Run** tugmasini bosing
3. "Success" xabari chiqishi kerak

### Qadam 4: Tekshirish

1. **Table Editor** ga kiring
2. Quyidagi jadvallar ko'rinishi kerak:
   - ✅ `users` (department_id ustuni bor)
   - ✅ `departments` (3 ta test bo'lim)

3. **Authentication** → **Users** ga kiring
4. Trigger ishlayotganini tekshiring (yangi user yaratilganda users jadvaliga avtomatik qo'shilishi kerak)

## ⚠️ Eslatmalar:

- SQL migration bajarilishi kerak
- Agar xatolik chiqsa, console dagi xatolik xabari qanday?
- Trigger ishlayotganini tekshiring

---

**SQL ni bajaring va "Bajardim" deb yozing!**

XP: +20 (SQL Migration)  
Motivatsiya: SQL migration bajarilgandan keyin RLS Policy lar ishlaydi va user avtomatik yaratiladi! 🚀




