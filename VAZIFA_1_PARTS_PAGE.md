# 🎯 Vazifa 1: PartsPage ni Repository Pattern ga O'tkazish

## 📋 Nima Qilamiz?

PartsPage ni eski `PartService` dan yangi `PartRepository` ga o'tkazamiz.

## 🧭 Qadammalar:

### 1. Importlarni O'zgartirish
- ❌ `PartService` ni olib tashlash
- ✅ `PartRepository` ni qo'shish
- ✅ `ServiceLocator` ni qo'shish
- ✅ Domain `Part` entity ni qo'shish

### 2. Service ni Repository ga O'zgartirish
- ❌ `final PartService _partService = PartService();`
- ✅ `final PartRepository _partRepository = ServiceLocator.instance.partRepository;`

### 3. Metodlarni O'zgartirish
- `_partService.getAllParts()` → `_partRepository.getAllParts()`
- `_partService.searchParts()` → `_partRepository.searchParts()`
- `_partService.addPart()` → `_partRepository.createPart()`
- `_partService.updatePart()` → `_partRepository.updatePart()`
- `_partService.deletePart()` → `_partRepository.deletePart()`

### 4. Model dan Entity ga O'tkazish
- `PartModel` → `Part` entity
- Mapping qilish kerak

### 5. Error Handling Qo'shish
- `Either<Failure, Success>` pattern
- Loading states
- Error messages

---

## 📌 Menga Topshiriq:

1. `lib/presentation/pages/parts_page.dart` ni oching
2. Importlarni o'zgartiring
3. Service ni Repository ga o'zgartiring
4. Metodlarni yangilang
5. Error handling qo'shing

---

## ⏳ Kutish:

"Bajardim" deb yozing, keyin keyingi vazifaga o'tamiz.

---

## ⚠️ Eslatmalar:

- `PartModel` va `Part` entity o'rtasida mapping kerak
- `Either` pattern ishlatish kerak
- Loading va error states qo'shish kerak

---

## 🏆 Motivatsiya:

**XP: +30** 🎮  
**Progress: Vazifa 1/5** 📊

