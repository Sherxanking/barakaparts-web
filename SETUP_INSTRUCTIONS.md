# 🚀 Setup Instructions - Xavfsizlik bilan

## 1️⃣ .env Fayl Yaratish

### Step 1: .env.example ni nusxalash
```bash
cp .env.example .env
```

### Step 2: .env Faylni To'ldirish

`.env` faylni oching va quyidagilarni to'ldiring:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here

# ⚠️ MUHIM: Service role key bu yerda EMAS!
# Service role key faqat backend da bo'ladi!

# Backend API (agar mavjud bo'lsa)
BACKEND_API_URL=https://your-backend-api.com

# App Environment
APP_ENV=development
```

### Step 3: Supabase Keys Olish

1. [Supabase Dashboard](https://app.supabase.com) ga kiring
2. Project ni tanlang
3. **Settings** → **API** ga kiring
4. Quyidagilarni ko'chirib oling:
   - **Project URL** → `SUPABASE_URL`
   - **anon public** key → `SUPABASE_ANON_KEY`
   - ⚠️ **service_role** key → Backend da ishlatiladi (frontend da EMAS!)

## 2️⃣ Dependencies O'rnatish

```bash
flutter pub get
```

## 3️⃣ App ni Ishga Tushirish

```bash
flutter run
```

## 4️⃣ Tekshirish

App ishga tushganda console da quyidagi xabarlar ko'rinishi kerak:

```
✅ Environment variables loaded
✅ Supabase initialized successfully (ANON key)
```

Agar xatolik bo'lsa:
```
⚠️ .env fayl yuklanmadi: ...
⚠️ Supabase initialization failed: ...
📱 App offline mode da ishlaydi (Hive cache)
```

## 5️⃣ Xavfsizlik Tekshiruvi

### ✅ To'g'ri:
- [ ] `.env` fayl `.gitignore` da
- [ ] Service role key frontend kodda yo'q
- [ ] Faqat anon key ishlatilmoqda
- [ ] Barcha sensitive operatsiyalar backend orqali

### ❌ Noto'g'ri:
- [ ] Service role key `.env` faylda (frontend uchun)
- [ ] Keys hardcoded kodda
- [ ] `.env` fayl Git ga commit qilingan

## 🔒 Xavfsizlik Checklist

Har bir commit dan oldin tekshiring:

```bash
# .env fayl Git da yo'qligini tekshirish
git status | grep .env

# Service role key kodda yo'qligini tekshirish
grep -r "service_role" lib/

# Hardcoded keys yo'qligini tekshirish
grep -r "eyJ.*service" lib/
```

## 📋 Keyingi Qadamlar

1. ✅ .env fayl yaratildi
2. ✅ Dependencies o'rnatildi
3. ✅ App ishga tushdi
4. ⏭️ Backend API yaratish (agar kerak bo'lsa)
5. ⏭️ Sensitive operatsiyalarni backend ga ko'chirish

## 🆘 Yordam

Agar muammo bo'lsa:
1. `.env` fayl to'g'ri yaratilganini tekshiring
2. Supabase keys to'g'ri ekanligini tekshiring
3. Console da xatoliklarni ko'ring
4. `SECURITY_GUIDELINES.md` ni o'qing




