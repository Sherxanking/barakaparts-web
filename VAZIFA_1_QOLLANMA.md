# 📋 Vazifa 1: SQL Migration - Qo'llanma

## 🎯 Maqsad

SQL migration ni bajarish - bu RLS Policy lar, Trigger va department_id qo'shish uchun.

## 📁 Fayl

`supabase/migrations/001_auth_and_users_FIXED.sql`

## 🔧 Qanday Bajarish

### 1. Supabase Dashboard

1. [supabase.com](https://supabase.com) → Project
2. **SQL Editor** (chap menuda)

### 2. SQL ni Copy Qilish

1. `001_auth_and_users_FIXED.sql` faylini oching
2. Barcha kodni copy qiling (Ctrl+A, Ctrl+C)

### 3. SQL Editor da Bajarish

1. SQL Editor ga yozing (Ctrl+V)
2. **Run** tugmasini bosing
3. "Success" xabari chiqishi kerak

### 4. Tekshirish

**Table Editor** da:
- ✅ `users` jadvali
- ✅ `departments` jadvali (3 ta: Assembly, Packaging, Quality Control)

**Authentication** → **Users**:
- Yangi user yaratilganda avtomatik `users` jadvaliga qo'shilishi kerak

## ⚠️ Xatolik Bo'lsa

Agar xatolik chiqsa:
1. Console dagi xatolik xabari qanday?
2. Qaysi qatorda xatolik?
3. Xatolik xabari qanday?

---

**SQL ni bajaring va "Bajardim" deb yozing!**




