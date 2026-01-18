# Quick Worker Setup - Play Market Test

## Tez Qadamlar

### 1. Boss/Manager User'lar (To'liq ruxsat)

Supabase Dashboard → Authentication → Users → Add user:

**Boss 1:**
- Email: `boss@test.com`
- Password: `Boss123!`
- Auto Confirm: ✅
- Metadata:
```json
{
  "name": "Boss",
  "role": "boss"
}
```

**Boss 2:**
- Email: `admin@test.com`
- Password: `Admin123!`
- Auto Confirm: ✅
- Metadata:
```json
{
  "name": "Admin",
  "role": "boss"
}
```

**Manager:**
- Email: `manager@test.com`
- Password: `Manager123!`
- Auto Confirm: ✅
- Metadata:
```json
{
  "name": "Manager",
  "role": "manager"
}
```

### 2. Worker User'lar (Faqat ko'ra oladi)

Har bir worker uchun:

**Worker 1:**
- Email: `worker1@test.com`
- Password: `Worker123!`
- Auto Confirm: ✅
- Metadata:
```json
{
  "name": "Worker 1",
  "role": "worker"
}
```

**Worker 2:**
- Email: `worker2@test.com`
- Password: `Worker123!`
- Auto Confirm: ✅
- Metadata:
```json
{
  "name": "Worker 2",
  "role": "worker"
}
```

**Worker 3:**
- Email: `worker3@test.com`
- Password: `Worker123!`
- Auto Confirm: ✅
- Metadata:
```json
{
  "name": "Worker 3",
  "role": "worker"
}
```

### 3. Tekshirish

SQL Editor'da quyidagini bajaring:

```sql
-- Barcha user'larni ko'rish
SELECT 
  u.id,
  u.email,
  u.name,
  u.role,
  u.created_at
FROM public.users u
ORDER BY u.role, u.created_at;
```

**Kutilgan natija:**
- 2-3 ta `boss` role
- 1 ta `manager` role
- Bir nechta `worker` role

### 4. Profile Yaratish (Agar kerak bo'lsa)

Agar trigger ishlamagan bo'lsa, SQL Editor'da:

```sql
-- Barcha auth.users dan profile yaratish
INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  id,
  COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1)) as name,
  email,
  COALESCE(raw_user_meta_data->>'role', 'worker') as role,
  created_at
FROM auth.users
WHERE NOT EXISTS (
  SELECT 1 FROM public.users WHERE id = auth.users.id
);
```

## Test Qilish

1. App'ni oching
2. Worker email/parol bilan login qiling
3. Tekshiring:
   - ✅ Barcha ma'lumotlarni ko'ra olishi kerak
   - ❌ Add/Edit/Delete tugmalari ko'rinmasligi kerak
4. Boss email/parol bilan login qiling
5. Tekshiring:
   - ✅ Barcha funksiyalar ishlashi kerak
   - ✅ Add/Edit/Delete tugmalari ko'rinishi kerak

## Xavfsizlik

⚠️ **Production'da:**
- `@test.com` domain ishlatmang
- Kuchli parollar ishlating
- Har bir user uchun unique email

✅ **Test uchun:**
- `@test.com` domain ishlatish mumkin
- Oddiy parollar ishlatish mumkin



