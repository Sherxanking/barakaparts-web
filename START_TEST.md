# 🚀 App'ni Ishga Tushirish va Test Qilish

## ⚡ Tezkor Boshlash

### Chrome'da Test (Eng Tezkor)

Quyidagi buyruqni terminal'da bajarib, app'ni Chrome'da oching:

```bash
flutter run -d chrome
```

**Yoki** VS Code'da:
1. F5 tugmasini bosing
2. Chrome'ni tanlang

---

## ✅ Asosiy Testlar

### 1. Login Test (30 soniya)
- [ ] Login sahifasi ochilishi kerak
- [ ] Email/Password bilan login qiling
- [ ] HomePage ochilishi kerak

### 2. Sahifalar Test (2 daqiqa)
- [ ] **Parts** sahifasiga kiring → Parts ko'rinishi kerak
- [ ] **Products** sahifasiga kiring → Products ko'rinishi kerak
- [ ] **Orders** sahifasiga kiring → Orders ko'rinishi kerak
- [ ] **Departments** sahifasiga kiring → Departments ko'rinishi kerak

### 3. CRUD Test (3 daqiqa)
- [ ] **Part qo'shish:** Parts → + → Name, Quantity → Add
- [ ] **Product qo'shish:** Products → + → Name, Department, Parts → Add
- [ ] **Order yaratish:** Orders → Department, Product, Quantity → Create
- [ ] **Department qo'shish:** Departments → + → Name → Add

### 4. Search/Filter Test (1 daqiqa)
- [ ] Search bar'da qidiruv qiling
- [ ] Filter'larni sinab ko'ring
- [ ] Sort'ni sinab ko'ring

---

## ⚠️ Xatoliklar

Agar xatolik bo'lsa:

1. **Console'ni oching:** F12 → Console
2. **Xatolik xabarini ko'ring**
3. **Quyidagilarni tekshiring:**
   - Internet aloqasi
   - Supabase connection
   - `.env` fayl mavjudligi

---

## 📊 Test Natijalari

### ✅ Muvaffaqiyatli:
- [ ] Login ishlayapti
- [ ] Barcha sahifalar ochilmoqda
- [ ] Ma'lumotlar ko'rinmoqda
- [ ] CRUD operatsiyalar ishlayapti

### ❌ Xatoliklar:
Agar xatolik bo'lsa, quyidagilarni yozing:
1. Qaysi sahifada?
2. Qanday amal bajarilganda?
3. Xatolik xabari nima?

---

## 🎯 Keyingi Qadamlar

Agar barcha testlar muvaffaqiyatli bo'lsa:
1. ✅ Real-time UI integration
2. ✅ Role-based UI
3. ✅ Signup sahifasi

















