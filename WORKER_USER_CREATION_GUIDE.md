# Worker User Yaratish Qo'llanmasi

## Maqsad
Play Market'da test qilish uchun worker'lar yaratish. Worker'lar faqat ko'ra oladi (read-only), boss va manager'lar to'liq ruxsatga ega.

## Role'lar

### 1. **worker** (Faqat ko'ra oladi)
- ✅ Barcha ma'lumotlarni ko'ra oladi
- ❌ Yaratish, tahrirlash, o'chirish mumkin emas
- ❌ Order yaratish mumkin (bu umumiy ruxsat)

### 2. **manager** (Ko'ra oladi, yaratadi, tahrirlaydi)
- ✅ Barcha ma'lumotlarni ko'ra oladi
- ✅ Yaratish va tahrirlash mumkin
- ❌ O'chirish mumkin emas (faqat boss)

### 3. **boss** (To'liq ruxsat)
- ✅ Barcha narsalarni qila oladi
- ✅ O'chirish ham mumkin

## Worker Yaratish Usullari

### Usul 1: Supabase Dashboard orqali (ENG OSON - Tavsiya etiladi)

1. **Supabase Dashboard** ga kiring: https://supabase.com/dashboard
2. Loyihangizni tanlang
3. **Authentication** → **Users** bo'limiga o'ting
4. **Add user** yoki **Invite user** tugmasini bosing
5. Quyidagi ma'lumotlarni kiriting:
   - **Email**: `worker1@test.com` (yoki istalgan email)
   - **Password**: Xavfsiz parol (masalan: `Worker123!`)
   - **Auto Confirm User**: ✅ (checkbox'ni belgilang - email tasdiqlashni o'tkazib yuboradi)
   - **User Metadata** (JSON formatida):
     ```json
     {
       "name": "Worker 1",
       "role": "worker"
     }
     ```
6. **Create user** tugmasini bosing

**Eslatma:** 
- Trigger avtomatik ravishda `public.users` jadvalida profile yaratadi
- Agar profile yaratilmagan bo'lsa, SQL Editor'da quyidagini bajaring (pastda)

### Usul 1.1: Agar trigger ishlamagan bo'lsa (Profile yaratish)

Supabase Dashboard → **SQL Editor** ga o'ting va quyidagini bajaring:

```sql
-- Worker user'ning profile'ini yaratish (agar trigger ishlamagan bo'lsa)
INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  id,
  COALESCE(raw_user_meta_data->>'name', 'Worker') as name,
  email,
  COALESCE(raw_user_meta_data->>'role', 'worker') as role,
  created_at
FROM auth.users
WHERE email = 'worker1@test.com'  -- O'zgartiring
  AND NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.users.id
  );
```

### Usul 2: SQL orqali (To'g'ridan-to'g'ri)

Supabase Dashboard → **SQL Editor** ga o'ting va quyidagi SQL'ni bajaring:

```sql
-- Worker yaratish
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'worker1@test.com',  -- O'zgartiring
  crypt('Worker123!', gen_salt('bf')),  -- Parolni o'zgartiring
  NOW(),
  '{"name": "Worker 1", "role": "worker"}'::jsonb,
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
);

-- Trigger avtomatik ravishda public.users jadvalida profile yaratadi
-- Agar profile yaratilmagan bo'lsa, quyidagini bajaring:
INSERT INTO public.users (id, name, email, role, created_at)
SELECT 
  id,
  raw_user_meta_data->>'name' as name,
  email,
  COALESCE(raw_user_meta_data->>'role', 'worker') as role,
  created_at
FROM auth.users
WHERE email = 'worker1@test.com'
ON CONFLICT (id) DO NOTHING;
```

### Usul 3: Flutter App orqali (Agar admin panel bo'lsa)

Agar app'da admin panel bo'lsa, u yerda:
1. Admin panel'ga kiring (boss yoki manager sifatida)
2. "Create User" yoki "Add Worker" tugmasini bosing
3. Ma'lumotlarni kiriting:
   - Name: Worker 1
   - Email: worker1@test.com
   - Password: Worker123!
   - Role: worker
4. Create tugmasini bosing

## Test User'lar Ro'yxati

### Boss'lar (To'liq ruxsat):
- `boss@test.com` / `Boss123!`
- `admin@test.com` / `Admin123!`
- (2-3 kishi)

### Manager'lar (Yaratish/Tahrirlash):
- `manager@test.com` / `Manager123!`

### Worker'lar (Faqat ko'ra oladi):
- `worker1@test.com` / `Worker123!`
- `worker2@test.com` / `Worker123!`
- `worker3@test.com` / `Worker123!`
- (Kerakli miqdorda)

## Parol Qoidalari

- Kamida 6 belgi
- Tavsiya: Katta harf, kichik harf, raqam, maxsus belgi
- Misol: `Worker123!`, `Test123!`, `Pass123!`

## Tekshirish

Yaratilgan user'ni tekshirish:

```sql
-- Auth user'ni tekshirish
SELECT id, email, raw_user_meta_data->>'role' as role
FROM auth.users
WHERE email = 'worker1@test.com';

-- Public user profile'ni tekshirish
SELECT id, name, email, role
FROM public.users
WHERE email = 'worker1@test.com';
```

## Muammo Hal Qilish

### User yaratildi, lekin login qila olmayapti:
1. Email tasdiqlanganligini tekshiring: `email_confirmed_at` NULL bo'lmasligi kerak
2. Parol to'g'ri ekanligini tekshiring
3. `public.users` jadvalida profile mavjudligini tekshiring

### Role to'g'ri ishlamayapti:
1. `public.users.role` ni tekshiring (bu asosiy source)
2. `auth.users.raw_user_meta_data->>'role'` ni tekshiring
3. Agar mos kelmasa, `public.users.role` ni yangilang

### Trigger ishlamayapti:
```sql
-- Trigger'ni tekshirish
SELECT * FROM pg_trigger WHERE tgname = 'handle_new_user';

-- Agar trigger yo'q bo'lsa, migration'ni qayta bajaring
```

## Xavfsizlik Eslatmalari

⚠️ **Production'da:**
- Test email'lardan foydalanmang (`@test.com`)
- Kuchli parollar ishlating
- Har bir user uchun unique email
- Parollarni xavfsiz saqlang (password manager)

✅ **Test uchun:**
- `@test.com` domain ishlatish mumkin
- Oddiy parollar ishlatish mumkin
- Lekin yana ham xavfsiz bo'lishi yaxshi

