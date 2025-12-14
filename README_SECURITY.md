# 🔒 Xavfsizlik Qo'llanmasi - BarakaParts

## ⚠️ MUHIM XAVFSIZLIK QOIDALARI

### 1. Service Role Key
- ❌ **HECH QACHON** frontend kodda `service_role` key ishlatmang
- ❌ **HECH QACHON** Git repository ga `service_role` key qo'ymang
- ✅ Service role key faqat backend da environment variable sifatida
- ✅ Backend API layer orqali barcha sensitive operatsiyalar

### 2. Frontend (Flutter)
- ✅ Faqat `anon` key ishlatiladi
- ✅ `.env` fayl orqali key saqlash
- ✅ `.env` fayl `.gitignore` da bo'lishi kerak
- ✅ Barcha sensitive operatsiyalar backend API orqali

### 3. Backend API Layer
- ✅ Service role key environment variable sifatida
- ✅ Barcha CRUD operatsiyalar backend orqali
- ✅ Authentication backend orqali
- ✅ User management backend orqali

## 📋 Quick Start

### 1. .env Fayl Yaratish
```bash
cp .env.example .env
```

### 2. .env Faylni To'ldirish
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
# ⚠️ Service role key bu yerda EMAS!
```

### 3. Dependencies
```bash
flutter pub get
```

### 4. Run
```bash
flutter run
```

## 🔍 Xavfsizlik Tekshiruvi

### Git Commit dan Oldin:
```bash
# .env fayl Git da yo'qligini tekshirish
git status | grep .env

# Service role key kodda yo'qligini tekshirish
grep -r "service_role" lib/

# Hardcoded keys yo'qligini tekshirish
grep -r "eyJ.*service" lib/
```

## 📚 Qo'shimcha Ma'lumot

- `SECURITY_GUIDELINES.md` - Batafsil xavfsizlik qoidalari
- `BACKEND_API_GUIDE.md` - Backend API yaratish qo'llanmasi
- `SETUP_INSTRUCTIONS.md` - To'liq setup qo'llanmasi
- `FOLDER_STRUCTURE.md` - Folder struktura tushuntirishi

## ✅ Checklist

- [ ] .env fayl yaratildi
- [ ] .env fayl .gitignore da
- [ ] Service role key frontend da yo'q
- [ ] Faqat anon key ishlatilmoqda
- [ ] Barcha sensitive operatsiyalar backend orqali




