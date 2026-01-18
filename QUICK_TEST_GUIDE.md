# ⚡ Tezkor Test Qo'llanmasi

## 🚀 App'ni Ishga Tushirish

### 1. Web'da Test (Eng Tezkor)

```bash
flutter run -d chrome
```

Yoki:

```bash
flutter run -d web-server --web-port=8080
```

**Keyin:** Browser'da `http://localhost:8080` ga kiring

---

### 2. Android'da Test

```bash
flutter run
```

Yoki:

```bash
flutter run -d <device-id>
```

---

## ✅ Asosiy Testlar (5 daqiqa)

### Test 1: Login ✅
1. App ochilganda Login sahifasi ko'rinishi kerak
2. Email/Password bilan login qiling
3. **Kutilgan:** HomePage ochilishi kerak

### Test 2: Parts Ko'rish ✅
1. Parts sahifasiga kiring
2. **Kutilgan:** Parts ro'yxati ko'rinishi kerak
3. Search bar'da qidiruv qiling
4. **Kutilgan:** Filtrlangan natijalar ko'rinishi kerak

### Test 3: Products Ko'rish ✅
1. Products sahifasiga kiring
2. **Kutilgan:** Products ro'yxati ko'rinishi kerak

### Test 4: Orders Ko'rish ✅
1. Orders sahifasiga kiring
2. **Kutilgan:** Orders ro'yxati ko'rinishi kerak

### Test 5: Departments Ko'rish ✅
1. Departments sahifasiga kiring
2. **Kutilgan:** Departments ro'yxati ko'rinishi kerak

---

## ⚠️ Agar Xatolik Bo'lsa

### Xatolik 1: "No parts/products/orders found"
**Sabab:** Database bo'sh yoki connection muammosi
**Yechim:** 
- Supabase connection tekshirish
- Internet aloqasi tekshirish
- Console'da xatolik xabari (F12 → Console)

### Xatolik 2: "Permission denied"
**Sabab:** RLS policies to'g'ri ishlamayapti
**Yechim:**
- Migration bajarilganligini tekshirish
- User role'ni tekshirish
- `CHECK_MIGRATION_STATUS.sql` ni bajarish

### Xatolik 3: "Failed to load"
**Sabab:** Repository connection muammosi
**Yechim:**
- `.env` fayl tekshirish
- Supabase URL va ANON_KEY tekshirish
- Console log'larni ko'rish

---

## 📊 Test Natijalari

### ✅ Muvaffaqiyatli:
- [ ] Login ishlayapti
- [ ] Barcha sahifalar ochilmoqda
- [ ] Ma'lumotlar ko'rinmoqda
- [ ] Search/Filter ishlayapti

### ❌ Xatoliklar:
Agar xatolik bo'lsa, quyidagilarni yozing:
1. Qaysi sahifada?
2. Qanday amal bajarilganda?
3. Xatolik xabari nima?
4. Console log'lar (F12 → Console)

---

## 🎯 Keyingi Qadamlar

Agar barcha testlar muvaffaqiyatli bo'lsa:
1. ✅ Real-time UI integration
2. ✅ Role-based UI
3. ✅ Signup sahifasi
4. ✅ Excel Import
