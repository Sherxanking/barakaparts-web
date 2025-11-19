# Baraka Parts - Inventory & Order Management MVP

Flutter va Hive asosida qurilgan buyurtma va ombor boshqaruv tizimi (MVP).

## 📋 Loyiha haqida

Baraka Parts - bu inventory/order management tizimi bo'lib, quyidagi funksiyalarni ta'minlaydi:

- **Department Management** - Bo'limlarni boshqarish
- **Product Management** - Mahsulotlarni boshqarish
- **Part Management** - Qismlar inventarini boshqarish
- **Order Management** - Buyurtmalarni yaratish va boshqarish
- **Stock Management** - Ombor miqdorini avtomatik boshqarish

## 🏗️ Arxitektura

Loyiha quyidagi arxitekturaga asoslangan:

```
lib/
├── data/
│   ├── models/          # Hive modellar (Department, Product, Part, Order)
│   └── services/        # Business logic layer
│       ├── hive_box_service.dart
│       ├── department_service.dart
│       ├── product_service.dart
│       ├── part_service.dart
│       └── order_service.dart
├── presentation/
│   ├── pages/          # UI sahifalar
│   │   ├── home_page.dart
│   │   ├── orders_page.dart
│   │   ├── departments_page.dart
│   │   ├── products_page.dart
│   │   ├── parts_page.dart
│   │   └── department_details_page.dart
│   └── widgets/        # Reusable UI komponentlar
│       ├── search_bar_widget.dart
│       ├── filter_chip_widget.dart
│       ├── sort_dropdown_widget.dart
│       ├── empty_state_widget.dart
│       ├── loading_widget.dart
│       ├── status_badge_widget.dart
│       ├── animated_list_item.dart
│       ├── error_widget.dart
│       └── confirmation_dialog.dart
└── main.dart          # Entry point
```

## 🚀 O'rnatish va ishga tushirish

### Talablar

- Flutter SDK (3.9.0 yoki yuqori)
- Dart SDK
- Android Studio / VS Code

### O'rnatish

1. Repository ni clone qiling:
```bash
git clone <repository-url>
cd BarakaParts
```

2. Dependencies ni o'rnating:
```bash
flutter pub get
```

3. Hive adapterlarini generate qiling:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. Dasturni ishga tushiring:
```bash
flutter run
```

## 📱 Asosiy funksiyalar

### 1. Department Management
- Bo'limlarni qo'shish, tahrirlash, o'chirish
- Bo'limlarga mahsulotlar biriktirish
- Qidiruv va tartiblash

### 2. Product Management
- Mahsulotlarni qo'shish, tahrirlash, o'chirish
- Mahsulotlarga qismlar biriktirish
- Department bo'yicha filtrlash

### 3. Part Management
- Qismlarni qo'shish, tahrirlash, o'chirish
- Miqdorni boshqarish (oshirish/kamaytirish)
- Low stock ogohlantirishlari
- Qidiruv va filtrlash

### 4. Order Management
- Buyurtmalarni yaratish (Department → Product → Quantity)
- Buyurtmalarni ko'rish va boshqarish
- Buyurtmalarni complete qilish (stock reduction)
- Qidiruv, filtrlash va tartiblash
- Real-time yangilanishlar

## 🗄️ Ma'lumotlar bazasi

Loyiha Hive local storage ishlatadi. 4 ta asosiy box mavjud:

- `departmentsBox` - Bo'limlar
- `productsBox` - Mahsulotlar
- `partsBox` - Qismlar
- `ordersBox` - Buyurtmalar

### Default ma'lumotlar

Birinchi marta ishga tushirilganda, quyidagi test ma'lumotlari avtomatik yuklanadi:

**Parts:**
- Screw M5 (100 ta)
- Bolt M8 (50 ta)
- Washer (200 ta)
- Nut M5 (150 ta)

**Departments:**
- Assembly
- Packaging
- Quality Control

**Products:**
- Widget A (Screw M5 x2, Bolt M8 x1)
- Widget B (Screw M5 x4, Washer x2, Nut M5 x2)
- Widget C (Bolt M8 x2, Washer x4)

## 🎨 UI/UX Xususiyatlari

- ✅ Material Design 3
- ✅ Search funksiyasi (barcha sahifalarda)
- ✅ Filter va Sort funksiyalari
- ✅ Real-time yangilanishlar (ValueListenableBuilder)
- ✅ Animatsiyalar (fade-in, slide)
- ✅ Empty states
- ✅ Error handling
- ✅ Loading states
- ✅ Confirmation dialoglar

## 🔧 Texnologiyalar

- **Flutter** - UI framework
- **Hive** - Local storage
- **Hive Flutter** - Hive integration
- **UUID** - Unique ID generation

## 📝 Kod sifati

- ✅ Clean Architecture
- ✅ Service Layer Pattern
- ✅ Reusable Widgets
- ✅ Comprehensive Comments
- ✅ Error Handling
- ✅ Null Safety

## 🐛 Ma'lum muammolar va yechimlar

### "Selected department or product not found" xatosi

**Muammo:** Order yaratishda bu xato chiqadi.

**Yechim:** Service metodlarida ID bo'yicha qidirish to'g'rilandi. Hive boxda `get(id)` key bo'yicha qidiradi, ID emas. Shuning uchun `firstWhere` ishlatildi.

### Order delete muammosi

**Muammo:** Order o'chirishda noto'g'ri order o'chiriladi.

**Yechim:** Index o'rniga ID bo'yicha o'chirish implementatsiya qilindi.

## 🚧 Keyingi qadamlar (Roadmap)

- [ ] Unit testlar qo'shish
- [ ] Integration testlar
- [ ] Dark mode qo'shish
- [ ] Export/Import funksiyalari (JSON, CSV)
- [ ] Statistics dashboard
- [ ] Notifications
- [ ] Performance optimizatsiyalari (ID cache)
- [ ] Multi-language support

## 📄 License

Bu loyiha MVP sifatida yaratilgan va test maqsadida ishlatiladi.

## 👨‍💻 Yaratuvchi

Baraka Parts MVP - Flutter + Hive

---

**Eslatma:** Bu MVP versiyasi. Production uchun qo'shimcha testlar va optimizatsiyalar talab qilinadi.
