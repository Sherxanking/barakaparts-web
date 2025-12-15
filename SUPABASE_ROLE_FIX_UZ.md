# ✅ Supabase Dashboard User Role Fix

**Muammo:** Supabase Dashboard orqali yangi user yaratilganda role yo'qolmoqda

**Sabab:** Dashboard orqali yaratilganda metadata'da role bo'lmasligi mumkin

---

## 🔧 YECHIM

### STEP 1: Supabase Migratsiyasini Qo'llash

1. **Supabase Dashboard** → **SQL Editor**
2. `supabase/migrations/015_fix_role_for_dashboard_users.sql` faylini oching
3. Barcha SQL kodini bajarish

**Bu migratsiya:**
- ✅ Mavjud userlarni yangilaydi (role NULL bo'lsa 'worker')
- ✅ Trigger'ni yangilaydi (metadata'da role bo'lmasa ham 'worker' o'rnatadi)
- ✅ Role column'ni NOT NULL qiladi
- ✅ Default value 'worker' o'rnatadi
- ✅ Test accountlarni to'g'ri sozlaydi

---

## 📋 QADAMLAR

### 1. Migratsiyani Qo'llash

```sql
-- Supabase Dashboard → SQL Editor
-- supabase/migrations/015_fix_role_for_dashboard_users.sql
```

**Kutilgan natija:**
```
✅ Barcha userlar role ga ega
✅ Barcha userlar valid role ga ega
✅ Trigger yangilandi!
```

---

### 2. Tekshirish

#### 2.1. Mavjud Userlarni Tekshirish

```sql
-- Role NULL yoki invalid bo'lgan userlarni topish
SELECT id, email, role
FROM public.users
WHERE role IS NULL 
   OR role = ''
   OR role NOT IN ('worker', 'manager', 'boss');
```

**Kutilgan natija:** 0 qator (barcha userlar to'g'ri role ga ega)

---

#### 2.2. Trigger'ni Tekshirish

```sql
-- Trigger mavjudligini tekshirish
SELECT tgname, tgrelid::regclass
FROM pg_trigger
WHERE tgname = 'on_auth_user_created';
```

**Kutilgan natija:** 1 qator (trigger mavjud)

---

#### 2.3. Function'ni Tekshirish

```sql
-- Function SECURITY DEFINER ekanligini tekshirish
c
```

**Kutilgan natija:**
- `proname = handle_new_user`
- `prosecdef = true` (MUHIM!)

---

## 🧪 TEST QILISH

### Test 1: Dashboard Orqali User Yaratish

1. **Supabase Dashboard** → **Authentication** → **Users**
2. **Add User** → **Create new user**
3. Yangi user yarating:
   - Email: `test@example.com`
   - Password: `Test123!`
   - Auto Confirm User: ✅ ON
4. **Table Editor** → **users** jadvalini tekshiring

**Kutilgan natija:**
- ✅ User `public.users` jadvalida ko'rinadi
- ✅ Role: `worker` (default)

---

### Test 2: Metadata Bilan User Yaratish

1. **Supabase Dashboard** → **Authentication** → **Users**
2. **Add User** → **Create new user**
3. Yangi user yarating:
   - Email: `manager2@test.com`
   - Password: `Manager123!`
   - **User Metadata:**
     ```json
     {
       "role": "manager",
       "name": "Test Manager"
     }
     ```
4. **Table Editor** → **users** jadvalini tekshiring

**Kutilgan natija:**
- ✅ User `public.users` jadvalida ko'rinadi
- ✅ Role: `manager` (metadata'dan)

---

### Test 3: Flutter App'da User Yaratish

1. Flutter app'ni ishga tushiring
2. Boss yoki Manager sifatida login qiling
3. **Admin Panel** → **Create User**
4. Yangi user yarating

**Kutilgan natija:**
- ✅ User yaratiladi
- ✅ Role to'g'ri o'rnatiladi

---

## ✅ MUAMMOLAR HAL QILINDI

| Muammo | Holat | Yechim |
|--------|-------|--------|
| Dashboard user role yo'q | ✅ | Trigger default 'worker' o'rnatadi |
| Metadata'da role yo'q | ✅ | Default 'worker' ishlatiladi |
| Role NULL bo'lishi | ✅ | NOT NULL constraint qo'shildi |
| Invalid role | ✅ | Validatsiya qo'shildi |

---

## 🔍 QO'SHIMCHA TEKSHIRUVLAR

### Barcha Userlarni Ko'rish

```sql
SELECT 
  id,
  email,
  role,
  created_at
FROM public.users
ORDER BY created_at DESC;
```

---

### Role Taqsimoti

```sql
SELECT 
  role,
  COUNT(*) as user_count
FROM public.users
GROUP BY role
ORDER BY user_count DESC;
```

**Kutilgan natija:**
- `worker`: X ta user
- `manager`: Y ta user
- `boss`: Z ta user

---

## ❌ AGAR MUAMMO DAVOM ETSA

### Muammo 1: Role hali ham NULL

**Yechim:**
```sql
-- Barcha NULL role'larni 'worker' bilan yangilash
UPDATE public.users
SET role = 'worker'
WHERE role IS NULL;
```

---

### Muammo 2: Trigger ishlamayapti

**Yechim:**
```sql
-- Trigger'ni qayta yaratish
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

---

### Muammo 3: Function SECURITY DEFINER emas

**Yechim:**
```sql
-- Function'ni qayta yaratish
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER  -- MUHIM!
SET search_path = public
LANGUAGE plpgsql
AS $$
-- ... function body
$$;
```

---

## 📝 XULOSA

**Asosiy muammo:** Dashboard orqali yaratilgan userlarda role yo'qolmoqda.

**Yechim:**
1. ✅ Trigger'ni yangilash - metadata'da role bo'lmasa default 'worker'
2. ✅ Role column'ni NOT NULL qilish
3. ✅ Mavjud userlarni yangilash

**Fayl:** `supabase/migrations/015_fix_role_for_dashboard_users.sql`

**Endi:** Barcha yangi userlar (Dashboard orqali ham) role ga ega bo'ladi! 🎉




