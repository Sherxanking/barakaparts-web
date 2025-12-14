# Qadamma-Qadam Yo'riqnoma - BarakaParts Refactoring

## 📌 Umumiy Ko'rinish

Bu yo'riqnoma sizga qadamma-qadam nima qilish kerakligini ko'rsatadi. Har bir bosqichni ketma-ket bajaring.

---

## ✅ BOSQICH 1: Supabase Project Yaratish (15-20 daqiqa)

### 1.1. Account Yaratish
- [ ] [supabase.com](https://supabase.com) ga kiring
- [ ] "Start your project" tugmasini bosing
- [ ] GitHub yoki Email bilan ro'yxatdan o'ting
- [ ] Email ni tasdiqlang

### 1.2. Project Yaratish
- [ ] Dashboard da "New Project" tugmasini bosing
- [ ] **Name**: `barakaparts` yozing
- [ ] **Database Password**: Kuchli parol yozing (SAQLAB QO'YING!)
- [ ] **Region**: Eng yaqin regionni tanlang
- [ ] **Pricing Plan**: Free tanlang
- [ ] "Create new project" tugmasini bosing
- [ ] 2-3 daqiqa kutish (project yaratilmoqda)

### 1.3. Ma'lumotlarni Olish
- [ ] Project ochilgandan keyin, chap menudan **Settings** → **API** ga kiring
- [ ] **Project URL** ni ko'chirib oling (masalan: `https://xxxxx.supabase.co`)
- [ ] **anon public** key ni ko'chirib oling (uzun matn)
- [ ] Bu ma'lumotlarni notepad ga saqlang

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 2: Database Schema Yaratish (20-30 daqiqa)

### 2.1. SQL Editor ga Kirish
- [ ] Supabase Dashboard da chap menudan **SQL Editor** ni tanlang
- [ ] "New query" tugmasini bosing

### 2.2. SQL Scriptni Bajarish
- [ ] `SUPABASE_SQL_COMPLETE.sql` faylini oching
- [ ] Barcha SQL kodini nusxalab oling
- [ ] SQL Editor ga yopishtiring
- [ ] "Run" tugmasini bosing (yoki F5)
- [ ] "Success" xabari chiqishini kutish

### 2.3. Tekshirish
- [ ] Chap menudan **Table Editor** ga kiring
- [ ] Quyidagi jadvallar ko'rinishi kerak:
  - [ ] ✅ users
  - [ ] ✅ departments
  - [ ] ✅ parts
  - [ ] ✅ products
  - [ ] ✅ orders
  - [ ] ✅ logs

**⚠️ Agar jadvallar ko'rinmasa, SQL scriptni qayta bajaring**

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 3: Flutter App ga Supabase Qo'shish (10-15 daqiqa)

### 3.1. Dependencies O'rnatish
Terminal da quyidagi buyruqni bajaring:

```bash
cd E:\BarakaParts
flutter pub get
```

- [ ] Buyruq muvaffaqiyatli bajarildi
- [ ] Xatolik bo'lmasa davom eting

### 3.2. Constants Faylini Yangilash
- [ ] `lib/core/utils/constants.dart` faylini oching
- [ ] Quyidagi qatorlarni toping:
  ```dart
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  ```
- [ ] `YOUR_SUPABASE_URL` o'rniga Supabase dan olgan URL ni yozing
- [ ] `YOUR_SUPABASE_ANON_KEY` o'rniga Supabase dan olgan key ni yozing
- [ ] Faylni saqlang (Ctrl+S)

**Misol:**
```dart
static const String supabaseUrl = 'https://abcdefgh.supabase.co';
static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

### 3.3. main.dart ni Yangilash
- [ ] `lib/main.dart` faylini oching
- [ ] Fayl boshiga quyidagi import qo'shing:
  ```dart
  import 'package:supabase_flutter/supabase_flutter.dart';
  import 'core/utils/constants.dart';
  import 'infrastructure/datasources/supabase_client.dart';
  ```
- [ ] `main()` funksiyasini toping
- [ ] `WidgetsFlutterBinding.ensureInitialized();` dan keyin quyidagini qo'shing:
  ```dart
  // Supabase ni initialize qilish
  try {
    await SupabaseClient.initialize();
    print('✅ Supabase initialized successfully');
  } catch (e) {
    print('❌ Supabase initialization failed: $e');
  }
  ```
- [ ] Faylni saqlang

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 4: Test Qilish (5-10 daqiqa)

### 4.1. App ni Ishga Tushirish
- [ ] Terminal da: `flutter run`
- [ ] App ishga tushdi
- [ ] Console da quyidagi xabar chiqishi kerak:
  ```
  ✅ Supabase initialized successfully
  ```

### 4.2. Xatoliklar
Agar xatolik bo'lsa:

**Xatolik 1: "Invalid API key"**
- [ ] `constants.dart` dagi URL va Key ni qayta tekshiring
- [ ] Supabase Dashboard → Settings → API dan to'g'ri ma'lumotlarni oling

**Xatolik 2: "Connection failed"**
- [ ] Internet aloqani tekshiring
- [ ] Supabase project faol ekanligini tekshiring

**Xatolik 3: "Table does not exist"**
- [ ] SQL scriptni qayta bajaring
- [ ] Table Editor da jadvallar borligini tekshiring

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 5: Qolgan Infrastructure Yaratish (1-2 soat)

### 5.1. Department Datasource
- [ ] `lib/infrastructure/datasources/supabase_department_datasource.dart` faylini yarating
- [ ] `supabase_part_datasource.dart` ni namuna sifatida ishlating
- [ ] Barcha metodlarni yozing (getAllDepartments, createDepartment, va h.k.)

### 5.2. User Datasource
- [ ] `lib/infrastructure/datasources/supabase_user_datasource.dart` faylini yarating
- [ ] Authentication metodlarini yozing

### 5.3. Log Datasource
- [ ] `lib/infrastructure/datasources/supabase_log_datasource.dart` faylini yarating
- [ ] Log yaratish va olish metodlarini yozing

### 5.4. Hive Cache Implementations
Har bir entity uchun:
- [ ] Hive model yarating (masalan: `hive_product_model.dart`)
- [ ] Hive cache yarating (masalan: `hive_product_cache.dart`)
- [ ] `build_runner` ni ishga tushiring:
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```

### 5.5. Repository Implementations
Har bir entity uchun:
- [ ] Repository implementation yarating (masalan: `product_repository_impl.dart`)
- [ ] `part_repository_impl.dart` ni namuna sifatida ishlating
- [ ] Service locator ga qo'shing

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 6: UI Sahifalarni Yangilash (2-3 soat)

### 6.1. Parts Page
- [ ] `lib/presentation/pages/parts_page.dart` ni oching
- [ ] Icon buttonlarni PopupMenuButton ga o'zgartiring
- [ ] Overflow muammosini tuzating
- [ ] Debounced search qo'shing (300ms)

### 6.2. Orders Page
- [ ] `lib/presentation/pages/orders_page.dart` ni oching
- [ ] RefreshIndicator muammosini tuzating
- [ ] ListView optimizatsiyasini qiling
- [ ] "This month total produced" ko'rsatkichini qo'shing

### 6.3. Product Edit Page
- [ ] `lib/presentation/pages/product_edit_page.dart` ni oching
- [ ] Crash muammosini tuzating
- [ ] JSON mapping ni to'g'rilang
- [ ] Validation qo'shing

### 6.4. Barcha Sahifalarni Repository ga O'tkazish
- [ ] Har bir sahifada to'g'ridan-to'g'ri service chaqiruvlarini repository ga o'zgartiring
- [ ] Service locator orqali repository larni oling
- [ ] Error handling qo'shing

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 7: Authentication Qo'shish (1-2 soat)

### 7.1. Login Page
- [ ] `lib/presentation/pages/login_page.dart` yarating
- [ ] Email/Phone va Password inputlari qo'shing
- [ ] Supabase authentication integratsiyasi

### 7.2. User Session Management
- [ ] Current user ni saqlash
- [ ] Session tekshirish
- [ ] Auto-logout

### 7.3. Route Protection
- [ ] Authentication kerak bo'lgan sahifalarni himoya qiling
- [ ] Role-based access control

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 8: Multi-Language (1 soat)

### 8.1. ARB Fayllar
- [ ] `lib/l10n/app_uz.arb` yarating
- [ ] `lib/l10n/app_ru.arb` yarating
- [ ] `lib/l10n/app_en.arb` yarating

### 8.2. Hardcoded Stringlarni Olib Tashlash
- [ ] Barcha sahifalarda hardcoded stringlarni toping
- [ ] ARB fayllarga ko'chiring
- [ ] Localization keylaridan foydalaning

### 8.3. Language Switcher
- [ ] Settings sahifasiga language switcher qo'shing
- [ ] Preference ni saqlash

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 9: Analytics va Reporting (1-2 soat)

### 9.1. Analytics Service
- [ ] `lib/application/services/analytics_service.dart` yarating
- [ ] Monthly production count
- [ ] Parts usage history
- [ ] Department-based reporting

### 9.2. Analytics Dashboard
- [ ] Analytics sahifasi yarating
- [ ] Charts va grafiklar qo'shing
- [ ] Date filters

**✅ Bu bosqich tugagach, keyingi bosqichga o'ting**

---

## ✅ BOSQICH 10: Final Testing va Polish (2-3 soat)

### 10.1. Functionality Testing
- [ ] Barcha CRUD operatsiyalar ishlayaptimi?
- [ ] Real-time updates ishlayaptimi?
- [ ] Offline mode ishlayaptimi?
- [ ] Permissions to'g'ri ishlayaptimi?

### 10.2. UI/UX Testing
- [ ] Barcha sahifalar chiroyli ko'rinayaptimi?
- [ ] Overflow muammolari bormi?
- [ ] Loading states ko'rsatilayaptimi?
- [ ] Error messages to'g'rimi?

### 10.3. Performance Testing
- [ ] App tez ishlayaptimi?
- [ ] Memory leaks bormi?
- [ ] Network requests optimallashtirilganmi?

**✅ Bu bosqich tugagach, loyiha tayyor!**

---

## 📝 Eslatmalar

1. **Har bir bosqichni yakunlang** - keyingi bosqichga o'tmasdan oldin
2. **Xatoliklarni darhol tuzating** - keyinroq qiyin bo'ladi
3. **Git commit qiling** - har bir muhim o'zgarishdan keyin
4. **Test qiling** - har bir funksiyani test qiling
5. **Hujjatlashtiring** - o'z o'zgarishlaringizni yozib qo'ying

## 🆘 Yordam

Agar muammo bo'lsa:
1. `SUPABASE_SETUP_GUIDE.md` ni o'qing
2. `REFACTORING_GUIDE.md` ni tekshiring
3. Console da xatoliklarni ko'ring
4. Supabase Dashboard → Logs ni tekshiring

---

## 🎯 Progress Tracking

Har bir bosqichni yakunlaganingizda, checkbox ni belgilang:

- [ ] Bosqich 1: Supabase Project
- [ ] Bosqich 2: Database Schema
- [ ] Bosqich 3: Flutter Integration
- [ ] Bosqich 4: Testing
- [ ] Bosqich 5: Infrastructure
- [ ] Bosqich 6: UI Updates
- [ ] Bosqich 7: Authentication
- [ ] Bosqich 8: Multi-Language
- [ ] Bosqich 9: Analytics
- [ ] Bosqich 10: Final Testing

**Omad! 🚀**

