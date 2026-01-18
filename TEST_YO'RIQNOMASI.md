# 🧪 BarakaParts App Test Yo'riqnomasi

## 📱 Manual Test (Qo'lda Tekshirish)

### 1. **Appni Ishga Tushirish**

```bash
# Android telefon/emulator uchun
flutter run

# Chrome uchun
flutter run -d chrome

# Windows uchun
flutter run -d windows
```

---

## ✅ Asosiy Funksiyalar Testi

### **TEST 1: Appni Birinchi Marta O'rnatish**

**Vazifa:** Appni to'liq o'chirib, qayta o'rnatish

**Qadamlar:**
1. Appni to'liq o'chirish (uninstall)
2. Appni qayta o'rnatish
3. Appni ochish

**Kutilgan natija:**
- ✅ App ochiladi
- ✅ Supabase'dan ma'lumotlar yuklanadi
- ✅ Agar Supabase'da ma'lumotlar bo'sh bo'lsa, default ma'lumotlar yuklanadi
- ✅ Debug console'da quyidagi log'lar ko'rinadi:
  - `🔍 Box'lar holati: parts=X, products=Y, orders=Z, departments=W`
  - `📥 Box'lar bo'sh, Supabase'dan ma'lumotlarni yuklayapman...`
  - `✅ X ta part yuklandi Supabase'dan`
  - `✅ X ta part Hive box'ga yozildi`

**Tekshirish:**
- Parts sahifasida ma'lumotlar ko'rinadi
- Products sahifasida ma'lumotlar ko'rinadi
- Orders sahifasida ma'lumotlar ko'rinadi
- Departments sahifasida ma'lumotlar ko'rinadi

---

### **TEST 2: Parts CRUD (Create, Read, Update, Delete)**

**Qadamlar:**

1. **Part Qo'shish:**
   - Parts sahifasiga o'ting
   - "+" tugmasini bosing
   - Part nomi kiriting (masalan: "Test Part")
   - Quantity kiriting (masalan: 100)
   - Min Quantity kiriting (masalan: 20)
   - Rasm qo'shing (ixtiyoriy)
   - "Add" tugmasini bosing

2. **Part Ko'rish:**
   - Qo'shilgan part ro'yxatda ko'rinishi kerak
   - Status to'g'ri ko'rsatilishi kerak (available/lowstock)

3. **Part Tahrirlash:**
   - Part ustiga bosing
   - Nom yoki quantity'ni o'zgartiring
   - "Save" tugmasini bosing

4. **Part O'chirish:**
   - Part ustiga bosing
   - "Delete" tugmasini bosing
   - Tasdiqlash dialogida "Yes" ni bosing

**Kutilgan natija:**
- ✅ Part qo'shiladi
- ✅ Part ko'rinadi
- ✅ Part yangilanadi
- ✅ Part o'chiriladi
- ✅ Barcha o'zgarishlar Supabase'ga yoziladi
- ✅ Barcha qurilmalarda (Chrome, telefon) bir xil ko'rinadi

---

### **TEST 3: Products CRUD**

**Qadamlar:**

1. **Product Qo'shish:**
   - Products sahifasiga o'ting
   - "+" tugmasini bosing
   - Product nomi kiriting
   - Department tanlang
   - "Select Parts" tugmasini bosing
   - Bir nechta part tanlang va quantity kiriting
   - "Add" tugmasini bosing

2. **Product Ko'rish:**
   - Qo'shilgan product ro'yxatda ko'rinishi kerak
   - Parts to'g'ri ko'rsatilishi kerak

3. **Product Tahrirlash:**
   - Product ustiga bosing
   - Nom yoki parts'ni o'zgartiring
   - "Save" tugmasini bosing

4. **Product O'chirish:**
   - Product ustiga bosing
   - "Delete" tugmasini bosing

**Kutilgan natija:**
- ✅ Product qo'shiladi
- ✅ Product ko'rinadi
- ✅ Product yangilanadi
- ✅ Product o'chiriladi
- ✅ Real-time yangilanishlar ishlaydi

---

### **TEST 4: Orders CRUD**

**Qadamlar:**

1. **Order Yaratish:**
   - Orders sahifasiga o'ting
   - "Create New Order" bo'limida:
     - Department tanlang
     - Product tanlang
     - Quantity kiriting
   - "Create Order" tugmasini bosing

2. **Order Ko'rish:**
   - Yaratilgan order ro'yxatda ko'rinishi kerak
   - Status "pending" bo'lishi kerak

3. **Order Complete Qilish:**
   - Order ustidagi "Complete" tugmasini bosing
   - Loading indicator ko'rsatilishi kerak
   - Order status "completed" bo'lishi kerak
   - Parts quantity kamayishi kerak

4. **Order O'chirish:**
   - Order ustidagi "Delete" tugmasini bosing
   - Tasdiqlash dialogida "Yes" ni bosing

**Kutilgan natija:**
- ✅ Order yaratiladi
- ✅ Order ko'rinadi
- ✅ Order complete qilinadi (tez, batch update bilan)
- ✅ Parts quantity to'g'ri kamayadi
- ✅ Order o'chiriladi
- ✅ Real-time yangilanishlar ishlaydi

---

### **TEST 5: Departments CRUD**

**Qadamlar:**

1. **Department Qo'shish:**
   - Departments sahifasiga o'ting
   - "+" tugmasini bosing
   - Department nomi kiriting
   - "Add" tugmasini bosing

2. **Department Ko'rish:**
   - Qo'shilgan department ro'yxatda ko'rinishi kerak

3. **Department Tahrirlash:**
   - Department ustiga bosing
   - Nomni o'zgartiring
   - "Save" tugmasini bosing

4. **Department O'chirish:**
   - Department ustiga bosing
   - "Delete" tugmasini bosing

**Kutilgan natija:**
- ✅ Department qo'shiladi
- ✅ Department ko'rinadi
- ✅ Department yangilanadi
- ✅ Department o'chiriladi

---

### **TEST 6: Real-time Yangilanishlar**

**Qadamlar:**

1. **Ikki Qurilmada Test:**
   - Chrome'da appni oching
   - Telefonda appni oching
   - Chrome'da part qo'shing
   - Telefonda part ko'rinishi kerak (avtomatik)

2. **Order Complete Test:**
   - Chrome'da order complete qiling
   - Telefonda order status "completed" bo'lishi kerak

**Kutilgan natija:**
- ✅ Barcha o'zgarishlar real-time ko'rinadi
- ✅ Barcha qurilmalarda bir xil ma'lumotlar
- ✅ UI avtomatik yangilanadi

---

### **TEST 7: Duplicate Name Validation**

**Qadamlar:**

1. **Part Duplicate:**
   - "Test Part" nomli part qo'shing
   - Yana "test part" (kichik harf) nomli part qo'shishga harakat qiling
   - Xatolik ko'rsatilishi kerak
   - Submit button disabled bo'lishi kerak

2. **Product Duplicate:**
   - "Test Product" nomli product qo'shing
   - Yana "test product" nomli product qo'shishga harakat qiling
   - Xatolik ko'rsatilishi kerak

3. **Department Duplicate:**
   - "Test Department" nomli department qo'shing
   - Yana "test department" nomli department qo'shishga harakat qiling
   - Xatolik ko'rsatilishi kerak

**Kutilgan natija:**
- ✅ Duplicate nomlar bloklanadi
- ✅ Xatolik xabari ko'rsatiladi
- ✅ Submit button disabled bo'ladi
- ✅ App crash qilmaydi

---

### **TEST 8: Search va Filter**

**Qadamlar:**

1. **Search:**
   - Har qanday sahifada search bar'ga yozing
   - Natijalar darhol ko'rsatilishi kerak

2. **Filter:**
   - Status filter'ni tanlang
   - Department filter'ni tanlang
   - Natijalar filtrlanishi kerak

3. **Sort:**
   - Sort dropdown'dan variant tanlang
   - Natijalar tartiblanishi kerak

**Kutilgan natija:**
- ✅ Search ishlaydi
- ✅ Filter ishlaydi
- ✅ Sort ishlaydi

---

### **TEST 9: Localization (Til O'zgarishi)**

**Qadamlar:**

1. **Til O'zgartirish:**
   - Settings sahifasiga o'ting
   - Til tanlang (Uzbek/Russian/English)
   - Appni qayta ishga tushiring

2. **Tekshirish:**
   - Barcha matnlar tanlangan tilda ko'rsatilishi kerak
   - Status label'lar to'g'ri ko'rsatilishi kerak
   - Capitalization to'g'ri bo'lishi kerak

**Kutilgan natija:**
- ✅ Barcha matnlar lokalizatsiya qilingan
- ✅ Til o'zgarishi to'g'ri ishlaydi
- ✅ Hech qanday hardcoded string qolmaydi

---

### **TEST 10: Performance Test**

**Qadamlar:**

1. **Order Complete Performance:**
   - 10+ part'li product yaratish
   - Order yaratish
   - Order complete qilish
   - Vaqt o'lchash (3 soniyadan kam bo'lishi kerak)

2. **Ma'lumotlar Yuklash:**
   - Appni qayta ishga tushirish
   - Ma'lumotlar tez yuklanishi kerak

**Kutilgan natija:**
- ✅ Order complete tez ishlaydi (batch update)
- ✅ Ma'lumotlar tez yuklanadi
- ✅ UI responsive bo'ladi

---

## 🔧 Automated Test (Agar kerak bo'lsa)

### Unit Testlar

```bash
# Testlarni ishga tushirish
flutter test

# Test coverage
flutter test --coverage
```

### Widget Testlar

```bash
# Widget testlar
flutter test test/widget_test.dart
```

---

## 📊 Test Natijalari

Har bir testdan keyin quyidagilarni tekshiring:

- ✅ App crash qilmaydi
- ✅ Ma'lumotlar saqlanadi
- ✅ Real-time yangilanishlar ishlaydi
- ✅ UI to'g'ri ishlaydi
- ✅ Xatoliklar to'g'ri ko'rsatiladi
- ✅ Performance yaxshi

---

## 🐛 Xatoliklarni Topish

Agar muammo bo'lsa:

1. **Debug Console'ni tekshiring:**
   - `flutter run` qilganda console'da log'lar ko'rinadi
   - Xatoliklarni yozib oling

2. **Supabase Dashboard'ni tekshiring:**
   - Table Editor'da ma'lumotlar bor-yo'qligini tekshiring
   - Logs'da xatoliklar bor-yo'qligini tekshiring

3. **Hive Box'larni tekshiring:**
   - Debug console'da box'lar holati ko'rsatiladi
   - `🔍 Box'lar holati: parts=X, products=Y...`

---

## ✅ Test Checklist

- [ ] Appni birinchi marta o'rnatish
- [ ] Parts CRUD
- [ ] Products CRUD
- [ ] Orders CRUD
- [ ] Departments CRUD
- [ ] Real-time yangilanishlar
- [ ] Duplicate name validation
- [ ] Search va Filter
- [ ] Localization
- [ ] Performance
- [ ] Order complete optimizatsiyasi
- [ ] Hero widget xatolari yo'q
- [ ] Timeout muammolari yo'q

---

## 📝 Test Qayd Ettirish

Har bir testdan keyin quyidagilarni yozib oling:

- Test nomi
- Natija (✅/❌)
- Xatoliklar (agar bo'lsa)
- Screenshot (agar kerak bo'lsa)























