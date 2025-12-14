# ✅ Parts Yaratish Permission Error Fix

**Muammo:** "Permission denied: only managers and boss can create parts"

**Sabab:** 
1. User'ning role'i 'manager' yoki 'boss' emas
2. RLS policy to'g'ri ishlamayapti
3. INSERT policy WITH CHECK to'g'ri sozlanmagan

---

## 🔧 YECHIM

### STEP 1: Muammoni Aniqlash

**Fayl:** `DEBUG_PARTS_PERMISSION.sql`

Avval muammoni aniqlash uchun bu so'rovlarni bajarib, natijalarni ko'ring:

1. **Supabase Dashboard** → **SQL Editor**
2. `DEBUG_PARTS_PERMISSION.sql` faylini oching
3. Barcha so'rovlarni bajarib, natijalarni ko'ring

**Tekshirish:**
- Current user'ning role'i 'manager' yoki 'boss' bo'lishi kerak
- INSERT policy mavjud bo'lishi kerak
- RLS yoqilgan bo'lishi kerak

---

### STEP 2: SQL Migration'ni Qo'llash

**Fayl:** `FIX_PARTS_PERMISSION_FINAL.sql`

**Qadamlari:**
1. **Supabase Dashboard** → **SQL Editor**
2. `FIX_PARTS_PERMISSION_FINAL.sql` faylini oching
3. Barcha SQL kodini nusxalab, SQL Editor'ga yopishtiring
4. **RUN** tugmasini bosing

**Bu fix:**
- ✅ Parts table yaratadi/yangilaydi
- ✅ RLS policies'ni to'liq qayta yaratadi
- ✅ INSERT policy WITH CHECK bilan to'g'ri sozlaydi
- ✅ `public.users` table'dan role'ni o'qish
- ✅ Verification qo'shadi

---

## 📊 KUTILGAN NATIJA

Migration'dan keyin:

```
========================================
VERIFICATION RESULTS:
========================================
✅ RLS is ENABLED on public.parts
✅ Number of policies: 4 (expected: 4)
✅ INSERT policy EXISTS
Current User ID: <UUID>
Current User Role: manager (yoki boss)
✅ User CAN create parts
========================================
✅ Parts table RLS policies fixed!
```

---

## 🧪 TEKSHIRISH

### Query 1: User Role'ni Tekshirish

```sql
SELECT 
  id,
  email,
  role,
  created_at
FROM public.users
WHERE id = auth.uid();
```

**Kutilgan natija:** `role = 'manager'` yoki `role = 'boss'`

**Agar role 'worker' bo'lsa:**
- `SET_DEFAULT_ROLE_MANAGER.sql` ni bajarish kerak
- Yoki `SET_GOOGLE_LOGIN_MANAGER_ROLE.sql` ni bajarish kerak

---

### Query 2: RLS Policies'ni Tekshirish

```sql
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'parts' 
AND schemaname = 'public'
ORDER BY cmd, policyname;
```

**Kutilgan natija:** 
- 4 ta policy (SELECT, INSERT, UPDATE, DELETE)
- INSERT policy'da `with_check` bo'lishi kerak

---

### Query 3: Test - Parts Yaratish

App'da yangi part yaratishga urinib ko'ring. Agar hali ham xato bo'lsa, quyidagi so'rovni bajarib, natijani yuboring:

```sql
-- Current user'ning role'ini tekshirish
SELECT 
  id,
  email,
  role
FROM public.users
WHERE id = auth.uid();
```

---

## ✅ XULOSA

**Asosiy muammo:** 
1. User'ning role'i 'manager' yoki 'boss' emas
2. RLS policy to'g'ri ishlamayapti

**Yechim:**
1. ✅ User role'ni 'manager' qilish
2. ✅ RLS policies'ni qayta yaratish
3. ✅ INSERT policy WITH CHECK bilan to'g'ri sozlash

**Endi:** Parts yaratish ishlaydi! 🎉

---

## 📝 QO'SHIMCHA

### Agar Hali Ham Muammo Bo'lsa:

1. **User role'ni tekshiring:**
   ```sql
   SELECT id, email, role 
   FROM public.users 
   WHERE id = auth.uid();
   ```

2. **Agar role 'worker' bo'lsa:**
   - `SET_DEFAULT_ROLE_MANAGER.sql` ni bajarish
   - Yoki `SET_GOOGLE_LOGIN_MANAGER_ROLE.sql` ni bajarish

3. **RLS policies'ni tekshiring:**
   ```sql
   SELECT * FROM pg_policies 
   WHERE tablename = 'parts';
   ```

4. **App'ni qayta ishga tushiring:**
   - Flutter app'ni to'xtatib, qayta ishga tushiring
   - Login qilib, qayta urinib ko'ring

