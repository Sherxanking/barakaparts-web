# ✅ STEP 2: Unused Imports Tozalash

**Muammo:** Unused imports va deprecated metodlar

**Yechim:** Unused import'larni olib tashlash va deprecated metodlarni yangilash

---

## 📋 QADAMLAR

### 1. admin_panel_page.dart

**Fayl:** `lib/presentation/pages/admin_panel_page.dart`

**O'zgarish:**
```dart
// OLIB TASHLASH (Line 12):
import '../../core/errors/failures.dart';
```

---

### 2. reset_password_page.dart

**Fayl:** `lib/presentation/pages/auth/reset_password_page.dart`

**O'zgarish:**
```dart
// OLIB TASHLASH (Line 8):
import '../../../core/errors/failures.dart';
```

---

### 3. splash_page.dart

**Fayl:** `lib/presentation/pages/splash_page.dart`

**O'zgarish:**
```dart
// OLIB TASHLASH (Line 354-375):
void _showErrorAndNavigate(String message) {
  // ... butun metod
}
```

---

### 4. error_widget.dart

**Fayl:** `lib/presentation/widgets/error_widget.dart`

**O'zgarish:**
```dart
// OLDIN (Line 35):
color: Colors.red.withOpacity(0.6),

// ENDI:
color: Colors.red.withValues(alpha: 0.6),

// OLDIN (Line 50):
color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),

// ENDI:
color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
```

---

### 5. part_repository_impl.dart

**Fayl:** `lib/infrastructure/repositories/part_repository_impl.dart`

**O'zgarish:**
```dart
// Line 141: catchError handler return qilishi kerak
.catchError((e) {
  debugPrint('⚠️ Cache update error: $e');
  return <Failure, List<Part>>[]; // Return empty list on error
});
```

---

## ✅ TASDIQLASH

**Approve? [Yes/No]**







