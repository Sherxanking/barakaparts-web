# 📝 .env Fayl Yaratish - Qo'llanma

## ✅ .env Fayl Yaratildi!

`.env` fayl yaratildi. Endi Supabase ma'lumotlarini kiriting.

## 🔧 .env Faylni To'ldirish

### Qadam 1: Supabase Dashboard ga Kiring

1. [supabase.com](https://supabase.com) ga kiring
2. Project ni tanlang
3. **Settings** → **API** ga kiring

### Qadam 2: Ma'lumotlarni Oling

1. **Project URL** ni ko'chirib oling
   - Masalan: `https://abcdefghijklmnop.supabase.co`

2. **anon public** key ni ko'chirib oling
   - Masalan: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### Qadam 3: .env Faylni Tahrirlash

`.env` faylni oching va quyidagilarni to'ldiring:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
APP_ENV=development
```

**Misol:**
```env
SUPABASE_URL=https://abcdefghijklmnop.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiY2RlZmdoaWprbG1ub3AiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTYzODk2NzI5MCwiZXhwIjoxOTU0NTQzMjkwfQ.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
APP_ENV=development
```

## ⚠️ MUHIM Eslatmalar

1. **Faqat ANON key ishlatiladi!**
   - Service role key ishlatilmaydi
   - Service role key xavfsizlik xavfi

2. **.env fayl Git ga commit qilinmaydi**
   - `.gitignore` da mavjud
   - Xavfsizlik uchun

3. **Keylarni hech kimga bermang!**
   - Faqat o'zingiz bilishingiz kerak

## ✅ Tekshirish

App ni run qilganda console da quyidagi xabarlar ko'rinishi kerak:

```
✅ Environment variables loaded
✅ Supabase initialized: https://xxxxx.supabase.co
```

Agar xatolik bo'lsa:
```
⚠️ .env fayl yuklanmadi: ...
❌ Supabase initialization error: ...
```

## 🎯 Keyingi Qadamlar

1. ✅ .env fayl yaratildi
2. ⏭️ Supabase ma'lumotlarini kiriting
3. ⏭️ App ni qayta run qiling
4. ⏭️ Login qilib ko'ring

---

**PowerShell Buyruqlari:**

```powershell
# .env fayl yaratish
New-Item -Path .env -ItemType File -Force

# .env faylni ko'rish
Get-Content .env

# .env faylni tahrirlash (Notepad da)
notepad .env
```




