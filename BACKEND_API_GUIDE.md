# 🔐 Backend API Layer - Tavsiyalar

## 📋 Umumiy Ma'lumot

Frontend to'g'ridan-to'g'ri Supabase ga yozmaydi. Barcha sensitive operatsiyalar backend API orqali amalga oshiriladi.

## 🏗️ Backend Struktura

### Option 1: Supabase Edge Functions (Tavsiya etiladi)

```
supabase/
├── functions/
│   ├── create-part/
│   │   └── index.ts              # Service role key bu yerda
│   ├── update-part/
│   │   └── index.ts
│   ├── delete-part/
│   │   └── index.ts
│   ├── create-order/
│   │   └── index.ts
│   └── approve-order/
│       └── index.ts
```

**Xavfsizlik:**
- Service role key faqat Edge Functions da
- Environment variable sifatida saqlanadi
- Git ga commit qilinmaydi

### Option 2: Separate Backend (Node.js/Express, Python/FastAPI, yoki boshqa)

```
backend/
├── .env                          # Service role key bu yerda
├── src/
│   ├── routes/
│   │   ├── parts.routes.ts
│   │   ├── orders.routes.ts
│   │   └── auth.routes.ts
│   ├── services/
│   │   └── supabase.service.ts  # Service role key ishlatiladi
│   └── middleware/
│       └── auth.middleware.ts
```

## 🔒 Service Role Key Xavfsizligi

### ✅ To'g'ri:
```typescript
// backend/.env
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

// backend/src/services/supabase.service.ts
import { createClient } from '@supabase/supabase-js';

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!, // ✅ Service role key
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);
```

### ❌ Noto'g'ri:
```dart
// lib/infrastructure/datasources/supabase_client.dart
// ❌ Service role key bu yerda EMAS!
static const String serviceRoleKey = 'eyJ...'; // ❌❌❌
```

## 📡 API Endpoints Tavsiyalari

### Parts API
```
POST   /api/parts              # Create part (backend orqali)
PUT    /api/parts/:id         # Update part (backend orqali)
DELETE /api/parts/:id         # Delete part (backend orqali)
GET    /api/parts             # Get parts (anon key bilan frontend dan)
```

### Orders API
```
POST   /api/orders            # Create order
PUT    /api/orders/:id/approve # Approve order (backend orqali)
PUT    /api/orders/:id/reject  # Reject order (backend orqali)
GET    /api/orders            # Get orders
```

### Auth API
```
POST   /api/auth/login        # Login (backend orqali)
POST   /api/auth/register     # Register (backend orqali)
POST   /api/auth/logout       # Logout
GET    /api/auth/me           # Get current user
```

## 🔐 Authentication Flow

### Frontend (Flutter)
```dart
// ✅ To'g'ri: Backend API orqali
final response = await ApiClient.instance.post('/api/auth/login', data: {
  'email': email,
  'password': password,
});
```

### Backend (Edge Function yoki API)
```typescript
// ✅ Service role key ishlatiladi
const { data, error } = await supabaseAdmin.auth.signInWithPassword({
  email,
  password,
});
```

## 📋 Checklist

Backend API yaratishdan oldin:
- [ ] Service role key environment variable sifatida
- [ ] .env fayl .gitignore da
- [ ] Barcha sensitive operatsiyalar backend da
- [ ] Frontend faqat anon key ishlatadi
- [ ] Authentication backend orqali
- [ ] CRUD operatsiyalar backend orqali

## 🚀 Quick Start

### Supabase Edge Functions

1. **Edge Function yaratish:**
```bash
supabase functions new create-part
```

2. **Service role key sozlash:**
```bash
# Supabase Dashboard → Settings → API → service_role key ni oling
# Edge Function environment variable sifatida qo'shing
```

3. **Function kod:**
```typescript
// supabase/functions/create-part/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Service role key environment variable dan
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  // Part yaratish
  const { data, error } = await supabaseAdmin
    .from('parts')
    .insert(req.body)

  return new Response(JSON.stringify({ data, error }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

## ⚠️ MUHIM Eslatmalar

1. **Service role key hech qachon frontend da EMAS!**
2. **Barcha sensitive operatsiyalar backend orqali!**
3. **Environment variables Git ga commit qilinmaydi!**
4. **Frontend faqat anon key bilan read operatsiyalar!**




