# ✅ Parts Yaratish Permission Fix

**Muammo:** Yangi part ochib bo'lmayapti

**Sabab:** RLS policies `public.users` table'dan role'ni to'g'ri o'qiy olmayapti

---

## 🔧 YECHIM

### STEP 1: SQL Migration'ni Qo'llash

**Fayl:** `FIX_PARTS_CREATE_PERMISSION.sql`

**Qadamlari:**
1. **Supabase Dashboard** → **SQL Editor**
2. `FIX_PARTS_CREATE_PERMISSION.sql` faylini oching
3. Barcha SQL kodini nusxalab, SQL Editor'ga yopishtiring
4. **RUN** tugmasini bosing

**Bu fix:**
- ✅ Parts table yaratadi/yangilaydi
- ✅ RLS policies'ni to'g'rilaydi
- ✅ `public.users` table'dan role'ni o'qish
- ✅ Manager va Boss parts yaratishi mumkin
- ✅ Realtime yoqiladi

---

## 📊 KUTILGAN NATIJA

Migration'dan keyin:

```
✅ Parts table already exists (yoki created)
✅ RLS is ENABLED on public.parts
✅ Number of policies: 4 (expected: 4)
✅ Realtime is ENABLED for public.parts
========================================
✅ Parts table RLS policies fixed!
✅ Manager and Boss can now create parts
```

---

## 🧪 TEKSHIRISH

### Query 1: RLS Policies'ni Tekshirish

```sql
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'parts' AND schemaname = 'public';
```

**Kutilgan natija:** 4 ta policy (SELECT, INSERT, UPDATE, DELETE)

---

### Query 2: Realtime Yoqilganligini Tekshirish

```sql
SELECT 
  tablename,
  pubname
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'parts';
```

**Kutilgan natija:** 1 qator (realtime yoqilgan)

---

### Query 3: Parts Table Structure

```sql
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'parts'
ORDER BY ordinal_position;
```

**Kutilgan natija:** 
- `id`, `name`, `quantity`, `min_quantity`, `image_path`, `created_by`, `updated_by`, `created_at`, `updated_at`

---

## ✅ XULOSA

**Asosiy muammo:** RLS policies `public.users` table'dan role'ni o'qiy olmayapti.

**Yechim:**
1. ✅ RLS policies'ni qayta yaratish
2. ✅ `public.users` table'dan role'ni o'qish
3. ✅ Manager va Boss parts yaratishi mumkin

**Endi:** Parts yaratish ishlaydi! 🎉

---

## 📝 QO'SHIMCHA

Agar hali ham muammo bo'lsa:

1. **User role'ni tekshiring:**
   ```sql
   SELECT id, email, role 
   FROM public.users 
   WHERE id = auth.uid();
   ```

2. **Role 'manager' yoki 'boss' bo'lishi kerak**

3. **Agar role 'worker' bo'lsa, `SET_DEFAULT_ROLE_MANAGER.sql` ni bajarish kerak**















