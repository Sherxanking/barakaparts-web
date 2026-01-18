# Supabase Migrations - Minimal To'plam

⚠️ **ESLATMA:** Bu fayl faqat dokumentatsiya. SQL kod emas! Supabase'da ishga tushirmang!

---

## ✅ Kerakli Migrationlar (faqat 3 ta)

### 1. `1000_mvp_stabilization.sql` 
**Nima qiladi:**
- ✅ Users table yaratadi (id, name, email, role, updated_at)
- ✅ Parts, Products, Orders, Departments jadvallarini yaratadi
- ✅ Barcha RLS policies (boss/manager CUD, worker read-only)
- ✅ Realtime enable qiladi (parts, products, orders, departments)
- ✅ Indexes qo'shadi

### 2. `1001_prevent_duplicate_names.sql`
**Nima qiladi:**
- ✅ Mavjud duplikatlarni hal qiladi (rename qiladi)
- ✅ Parts uchun unique index (LOWER(TRIM(name)))
- ✅ Products uchun unique index (LOWER(TRIM(name)))
- ✅ Departments unique constraint tekshiradi

### 3. `1002_add_users_trigger.sql` (Ixtiyoriy)
**Nima qiladi:**
- ✅ Auth user yaratilganda avtomatik public.users ga qo'shish
- ✅ Role auto-detection (email bo'yicha)
- ✅ Name auto-extraction (metadata yoki email dan)

---


---

## ❌ Kerak EMAS (eski/takrorlanuvchi migrationlar)

Quyidagi migrationlar **kerak emas**, chunki 1000_mvp_stabilization.sql ularning barchasini qamrab oladi:

- ❌ 001_auth_and_users.sql (eski versiya)
- ❌ 002_auth_email_verification.sql
- ❌ 003_fix_rls_policies.sql
- ❌ 004_ensure_tables_and_fix_rls.sql
- ❌ 005_drop_all_policies_and_recreate.sql
- ❌ 006_fix_users_rls_recursion.sql
- ❌ 007_enable_realtime_for_parts.sql
- ❌ 008_rbac_parts_policies.sql
- ❌ 009_fix_parts_realtime_and_rls.sql
- ❌ 010_create_test_accounts.sql
- ❌ 011-022 (barcha fix migrationlar)
- ❌ 023_enable_realtime_products_orders.sql
- ❌ 999_mvp_permissions_reset.sql

---

## 📋 Ishga tushirish tartibi

1. **1000_mvp_stabilization.sql** ni ishga tushiring
2. **1001_prevent_duplicate_names.sql** ni ishga tushiring
3. (Ixtiyoriy) **1002_add_users_trigger.sql** ni ishga tushiring (auth userlar avtomatik yaratilishi uchun)

---

## ✅ Tekshirish

Migrationlardan keyin quyidagilarni tekshiring:

```sql
-- Jadvallar mavjudligi
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('users', 'parts', 'products', 'orders', 'departments');

-- RLS enabled
SELECT tablename, rowsecurity FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'parts', 'products', 'orders', 'departments');

-- Unique indexes
SELECT indexname FROM pg_indexes 
WHERE schemaname = 'public' 
AND indexname LIKE '%_name_unique';
```

