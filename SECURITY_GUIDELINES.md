# 🔒 Xavfsizlik Qoidalari - BarakaParts

## ⚠️ MUHIM: Xavfsizlik Qoidalari

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

### 4. Kod Struktura
- ✅ Clean Architecture
- ✅ Feature-first folder structure
- ✅ Separation of concerns
- ✅ Dependency injection

## 📋 Checklist

Har bir kod yozishdan oldin tekshiring:
- [ ] Service role key frontend da ishlatilmayaptimi?
- [ ] Anon key `.env` faylda saqlanayaptimi?
- [ ] `.env` fayl `.gitignore` da bormi?
- [ ] Sensitive operatsiyalar backend orqalimi?
- [ ] Clean Architecture qoidalariga rioya qilinayaptimi?




