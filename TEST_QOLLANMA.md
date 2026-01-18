# 🧪 App Test Qo'llanmasi

## ✅ Migration Bajarilgandan Keyin Test Qilish

---

## 📋 TEST CHECKLIST

### 1. 🔐 Authentication Test

#### 1.1. Login Test
- [ ] App'ni ishga tushiring (`flutter run`)
- [ ] Login sahifasiga kiring
- [ ] Email/Password bilan login qiling
- [ ] **Kutilgan:** HomePage ochilishi kerak
- [ ] **Xatolik bo'lsa:** Xatolik xabarini yozing

#### 1.2. Auto Login Test
- [ ] App'ni yoping
- [ ] Qayta oching
- [ ] **Kutilgan:** Agar oldin login qilgan bo'lsangiz, avtomatik HomePage ochilishi kerak
- [ ] **Xatolik bo'lsa:** Login sahifasiga qaytib ketmaydi

#### 1.3. Logout Test
- [ ] Settings sahifasiga kiring
- [ ] Logout tugmasini bosing
- [ ] **Kutilgan:** Login sahifasiga qaytish kerak

---

### 2. 📦 Parts Page Test

#### 2.1. Parts Ko'rish
- [ ] Parts sahifasiga kiring
- [ ] **Kutilgan:** Parts ro'yxati ko'rinishi kerak
- [ ] **Xatolik bo'lsa:** "No parts yet" yoki xatolik xabari

#### 2.2. Part Qo'shish (Boss/Manager)
- [ ] FloatingActionButton (+) tugmasini bosing
- [ ] Part name, quantity, min quantity kiriting
- [ ] Add tugmasini bosing
- [ ] **Kutilgan:** Part qo'shilishi va ro'yxatda ko'rinishi kerak
- [ ] **Xatolik bo'lsa:** Xatolik xabarini yozing

#### 2.3. Part Tahrirlash
- [ ] Part'ga bosing (yoki 3-dots menu → Edit)
- [ ] Ma'lumotlarni o'zgartiring
- [ ] Save tugmasini bosing
- [ ] **Kutilgan:** O'zgarishlar saqlanishi kerak

#### 2.4. Part O'chirish (Boss)
- [ ] 3-dots menu → Delete
- [ ] Tasdiqlash dialogida Delete tugmasini bosing
- [ ] **Kutilgan:** Part o'chirilishi kerak

#### 2.5. Search va Filter
- [ ] Search bar'da part nomini yozing
- [ ] **Kutilgan:** Faqat mos keladigan parts ko'rinishi kerak
- [ ] Low Stock filter'ni yoqing
- [ ] **Kutilgan:** Faqat kam qolgan parts ko'rinishi kerak

---

### 3. 📦 Products Page Test

#### 3.1. Products Ko'rish
- [ ] Products sahifasiga kiring
- [ ] **Kutilgan:** Products ro'yxati ko'rinishi kerak

#### 3.2. Product Qo'shish (Boss/Manager)
- [ ] FloatingActionButton (+) tugmasini bosing
- [ ] Product name kiriting
- [ ] Department tanlang
- [ ] Parts tanlang va miqdorni kiriting
- [ ] Add tugmasini bosing
- [ ] **Kutilgan:** Product qo'shilishi kerak

#### 3.3. Product Tahrirlash
- [ ] Product'ga bosing
- [ ] Ma'lumotlarni o'zgartiring
- [ ] **Kutilgan:** O'zgarishlar saqlanishi kerak

#### 3.4. Product O'chirish
- [ ] Delete tugmasini bosing
- [ ] Tasdiqlash dialogida Delete tugmasini bosing
- [ ] **Kutilgan:** Product o'chirilishi kerak

---

### 4. 📋 Orders Page Test

#### 4.1. Orders Ko'rish
- [ ] Orders sahifasiga kiring
- [ ] **Kutilgan:** Orders ro'yxati ko'rinishi kerak

#### 4.2. Order Yaratish
- [ ] Department tanlang
- [ ] Product tanlang
- [ ] Quantity kiriting
- [ ] Create Order tugmasini bosing
- [ ] **Kutilgan:** Order yaratilishi kerak

#### 4.3. Order Complete Qilish
- [ ] Order'da Complete tugmasini bosing
- [ ] **Kutilgan:** Order status "completed" bo'lishi kerak
- [ ] **Kutilgan:** Parts miqdori kamayishi kerak

#### 4.4. Order O'chirish
- [ ] Delete tugmasini bosing
- [ ] Tasdiqlash dialogida Delete tugmasini bosing
- [ ] **Kutilgan:** Order o'chirilishi kerak

---

### 5. 🏢 Departments Page Test

#### 5.1. Departments Ko'rish
- [ ] Departments sahifasiga kiring
- [ ] **Kutilgan:** Departments ro'yxati ko'rinishi kerak

#### 5.2. Department Qo'shish
- [ ] FloatingActionButton (+) tugmasini bosing
- [ ] Department name kiriting
- [ ] Add tugmasini bosing
- [ ] **Kutilgan:** Department qo'shilishi kerak

#### 5.3. Department Tahrirlash
- [ ] Edit tugmasini bosing
- [ ] Name'ni o'zgartiring
- [ ] Save tugmasini bosing
- [ ] **Kutilgan:** O'zgarishlar saqlanishi kerak

#### 5.4. Department O'chirish
- [ ] Delete tugmasini bosing
- [ ] Tasdiqlash dialogida Delete tugmasini bosing
- [ ] **Kutilgan:** Department o'chirilishi kerak

---

### 6. 🔄 Real-time Test (2 ta qurilma yoki browser tab)

#### 6.1. Real-time Yangilanish
- [ ] 2 ta browser tab oching (yoki 2 ta qurilma)
- [ ] Ikkalasida ham login qiling
- [ ] Bir tab'da Part qo'shing
- [ ] **Kutilgan:** Ikkinchi tab'da avtomatik yangilanishi kerak
- [ ] **Xatolik bo'lsa:** Real-time ishlamayapti

---

### 7. 🔐 Permission Test (Role-based)

#### 7.1. Worker Role Test
- [ ] Worker role bilan login qiling
- [ ] Parts sahifasiga kiring
- [ ] **Kutilgan:** FloatingActionButton (+) ko'rinmasligi kerak
- [ ] **Xatolik bo'lsa:** Worker ham qo'sha olayapti

#### 7.2. Manager Role Test
- [ ] Manager role bilan login qiling
- [ ] Parts sahifasiga kiring
- [ ] **Kutilgan:** FloatingActionButton (+) ko'rinishi kerak
- [ ] Part qo'shishga harakat qiling
- [ ] **Kutilgan:** Muvaffaqiyatli qo'shilishi kerak

#### 7.3. Boss Role Test
- [ ] Boss role bilan login qiling
- [ ] Barcha sahifalarda Delete tugmalari ko'rinishi kerak
- [ ] Delete qilishga harakat qiling
- [ ] **Kutilgan:** Muvaffaqiyatli o'chirilishi kerak

---

### 8. ⚠️ Xatoliklar Test

#### 8.1. Offline Test
- [ ] Internet'ni o'chiring
- [ ] App'ni ishlatishga harakat qiling
- [ ] **Kutilgan:** App ishlashi kerak (Hive cache'dan)
- [ ] **Xatolik bo'lsa:** App crash bo'lmaydi

#### 8.2. Validation Test
- [ ] Bo'sh Part name bilan qo'shishga harakat qiling
- [ ] **Kutilgan:** Xatolik xabari ko'rinishi kerak
- [ ] Manfiy quantity bilan qo'shishga harakat qiling
- [ ] **Kutilgan:** Xatolik xabari ko'rinishi kerak

---

## 📊 Test Natijalari

### ✅ Muvaffaqiyatli Testlar
- [ ] Authentication ishlayapti
- [ ] CRUD operatsiyalar ishlayapti
- [ ] Search va Filter ishlayapti
- [ ] Real-time yangilanishlar ishlayapti (agar yoqilgan bo'lsa)
- [ ] Permissions to'g'ri ishlayapti

### ❌ Xatoliklar
Agar xatolik bo'lsa, quyidagilarni yozing:
1. Qaysi sahifada xatolik?
2. Qanday amal bajarilganda xatolik?
3. Xatolik xabari nima?
4. Screenshot (agar mumkin bo'lsa)

---

## 🎯 Keyingi Qadamlar

Agar barcha testlar muvaffaqiyatli bo'lsa:
1. ✅ Real-time UI integration qo'shish
2. ✅ Role-based UI yaxshilash
3. ✅ Signup sahifasi qo'shish
4. ✅ Excel Import funksiyasi

---

## 🆘 Yordam

Agar muammo bo'lsa:
1. Xatolik xabarini ko'rsating
2. Qaysi qadamda xatolik bo'ldi?
3. Console log'larni tekshiring (F12 → Console)

















