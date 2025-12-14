# ✅ Parts Create Permission Fix - Test

**SQL bajarildi:** `FIX_PARTS_CREATE_PERMISSION_FINAL.sql`

---

## 🧪 TEST QADAMLARI

### Test 1: Google Login va Role Tekshirish

1. **App'ni to'liq yoping** (kill app)
2. **App'ni qayta oching**
3. **Google login qiling**
4. **Home page'ga o'ting**
5. **Settings yoki Profile page'ga o'ting** (agar mavjud bo'lsa)
6. **Role'ni tekshiring** - `manager` bo'lishi kerak

---

### Test 2: Parts Yaratish

1. **Parts page'ga o'ting**
2. **"+" tugmasini bosing** (yangi part yaratish)
3. **Part name:** "Test Part"
4. **Quantity:** 10
5. **Min Quantity:** 3
6. **"Add" tugmasini bosing**

**Kutilgan natija:**
- ✅ Part muvaffaqiyatli yaratiladi
- ✅ "Part added successfully" xabari
- ✅ Parts list'da ko'rinadi

---

### Test 3: Agar Hali Ham Xatolik Bo'lsa

Agar hali ham "Permission denied" xatosi bo'lsa:

1. **Logout qiling**
2. **Google login qiling** (qayta)
3. **Parts yaratishga urinib ko'ring**

---

## 🔍 DEBUG QUERIES

Agar muammo bo'lsa, quyidagi query'larni Supabase SQL Editor'da bajarib, natijani yuboring:

### Query 1: Joriy User Role'ni Tekshirish

```sql
SELECT 
  auth.uid() as current_user_id,
  pu.role as current_user_role,
  pu.email,
  CASE 
    WHEN pu.role IN ('manager', 'boss') THEN '✅ Can create parts'
    ELSE '❌ Cannot create parts'
  END as permission_status
FROM public.users pu
WHERE pu.id = auth.uid();
```

### Query 2: Google Userlarni Tekshirish

```sql
SELECT 
  au.id,
  au.email,
  pu.role,
  ai.provider,
  CASE 
    WHEN pu.role = 'manager' THEN '✅ Manager'
    WHEN pu.role = 'worker' THEN '❌ Worker (needs update)'
    ELSE '⚠️ Unknown'
  END as status
FROM auth.users au
INNER JOIN auth.identities ai ON au.id = ai.user_id
LEFT JOIN public.users pu ON au.id = pu.id
WHERE ai.provider = 'google';
```

### Query 3: Parts RLS Policies'ni Tekshirish

```sql
SELECT 
  policyname,
  cmd as command,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'parts'
ORDER BY policyname;
```

---

## ✅ TASDIQLASH

**Parts yaratish ishlayaptimi?** [Yes/No]

Agar "No" bo'lsa, debug query natijalarini yuboring.

