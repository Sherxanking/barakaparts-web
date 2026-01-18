# ✅ Google Login Manager Role Fix

**Muammo:** Google orqali sign qilganda default role 'worker' bo'lyapti

**Yechim:** Google orqali kirgan userlar avtomatik 'manager' role bilan yaratiladi

---

## 🔧 YECHIM

### STEP 1: SQL Migration'ni Qo'llash

**Fayl:** `SET_GOOGLE_LOGIN_MANAGER_ROLE.sql`

**Qadamlari:**
1. **Supabase Dashboard** → **SQL Editor**
2. `SET_GOOGLE_LOGIN_MANAGER_ROLE.sql` faylini oching
3. Barcha SQL kodini nusxalab, SQL Editor'ga yopishtiring
4. **RUN** tugmasini bosing

**Bu fix:**
- ✅ Trigger function'ni yangilaydi
- ✅ Google userlarni aniqlaydi
- ✅ Google userlar uchun default role 'manager'
- ✅ Mavjud Google userlarni yangilaydi
- ✅ Test accountlarni saqlab qoladi

---

## 📊 KUTILGAN NATIJA

Migration'dan keyin:

```
========================================
GOOGLE LOGIN ROLE STATISTICS:
========================================
✅ Google users: X
✅ Manager users: X
📊 Total users: X
========================================
✅ Trigger updated - Google login users will get MANAGER role
✅ Existing Google users updated to MANAGER role
```

---

## 🧪 TEKSHIRISH

### Query 1: Google Userlarni Tekshirish

```sql
SELECT 
  au.id,
  au.email,
  pu.role,
  ai.provider
FROM auth.users au
INNER JOIN auth.identities ai ON au.id = ai.user_id
LEFT JOIN public.users pu ON au.id = pu.id
WHERE ai.provider = 'google';
```

**Kutilgan natija:** Barcha Google userlar `role = 'manager'`

---

### Query 2: Role Distribution

```sql
SELECT role, COUNT(*) as count
FROM public.users
GROUP BY role
ORDER BY role;
```

**Kutilgan natija:**
- `boss`: 1 (boss@test.com)
- `manager`: X (barcha Google userlar va boshqa userlar)

---

### Query 3: Trigger Function'ni Tekshirish

```sql
SELECT 
  proname,
  prosrc
FROM pg_proc
WHERE proname = 'handle_new_user'
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
```

**Kutilgan natija:** Function mavjud va Google user detection logic bor

---

## ✅ XULOSA

**Asosiy muammo:** Google orqali sign qilganda default role 'worker' bo'lyapti.

**Yechim:**
1. ✅ Trigger function'ni yangilash
2. ✅ Google userlarni aniqlash
3. ✅ Google userlar uchun default role 'manager'
4. ✅ Mavjud Google userlarni yangilash

**Endi:** Google orqali sign qilganda manager roli bilan kiriladi! 🎉

---

## 📝 QO'SHIMCHA

### Google User Aniqlash Logic

Trigger function quyidagilarni tekshiradi:
1. `app_metadata->>'provider' = 'google'`
2. `raw_user_meta_data->>'provider' = 'google'`
3. `auth.identities` table'dan `provider = 'google'`

Agar bittasi ham to'g'ri bo'lsa, user Google user deb hisoblanadi va 'manager' role o'rnatiladi.

---

## ⚠️ MUHIM ESLATMA

- Test accountlar (`boss@test.com`, `manager@test.com`) o'zgarishsiz qoladi
- Metadata'da role bo'lsa, u ishlatiladi
- Google userlar avtomatik 'manager' role bilan yaratiladi
































