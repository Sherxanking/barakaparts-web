# Error Handling Guide

## Muammo
Production'da ko'p xatoliklar chiqadi, lekin development'da kam. Bu quyidagi sabablarga bog'liq:
- Network issues (internet tezligi, connectivity)
- Supabase RLS policies (permission muammolari)
- State management (real-time updates synchronization)
- Null safety (null check'lar yetarli emas)
- Loading states (loading holatlarida xatoliklar)

## Yechim

### 1. Global Error Handler ✅
`lib/core/services/error_handler_service.dart` yaratildi va `main.dart` ga qo'shildi.

**Qanday ishlaydi:**
- Barcha Flutter xatoliklarini catch qiladi (`FlutterError.onError`)
- Async xatoliklarni catch qiladi (`runZonedGuarded`)
- Platform-specific xatoliklarni catch qiladi (`PlatformDispatcher.onError`)

### 2. Error Display Widget ✅
`lib/presentation/widgets/error_widget.dart` yaratildi.

**Qanday ishlatish:**
```dart
// StreamBuilder'da
if (snapshot.hasError) {
  return ErrorDisplayWidget(
    error: snapshot.error,
    onRetry: () => setState(() => _isInitialLoading = true),
  );
}

// Failure bilan
final result = snapshot.data?.fold(
  (failure) {
    return ErrorDisplayWidget(
      failure: failure,
      onRetry: () => setState(() => _isInitialLoading = true),
    );
  },
  (data) => YourDataWidget(data: data),
);
```

### 3. User-friendly Error Messages ✅
`ErrorHandlerService.getErrorMessage()` - barcha failure'larni user-friendly message'ga o'zgartiradi.

**Qo'llab-quvvatlanadigan failure turlari:**
- `NetworkFailure` - "Internet aloqasi yo'q..."
- `ServerFailure` - Network, Database, Permission xatoliklari
- `AuthFailure` - Login, Email verification xatoliklari
- `ValidationFailure` - Validation xatoliklari
- `PermissionFailure` - Ruxsat xatoliklari
- `UnknownFailure` - Noma'lum xatoliklar

### 4. Error Logging ✅
Barcha xatoliklar console'ga log qilinadi (production'da Sentry yoki boshqa service'ga yuborish mumkin).

**Log format:**
```
═══════════════════════════════════════
❌ ERROR [2024-01-01T12:00:00.000Z]
═══════════════════════════════════════
Error: ...
Stack Trace: ...
Context: ...
═══════════════════════════════════════
```

## Qo'llash

### StreamBuilder'larda error handling yaxshilash

**Eski kod:**
```dart
if (snapshot.hasError) {
  return Scaffold(
    body: Center(
      child: Text('Error: ${snapshot.error}'),
    ),
  );
}
```

**Yangi kod:**
```dart
import '../widgets/error_widget.dart';
import '../../core/services/error_handler_service.dart';

if (snapshot.hasError) {
  return Scaffold(
    appBar: AppBar(...),
    body: ErrorDisplayWidget(
      error: snapshot.error,
      onRetry: () => setState(() => _isInitialLoading = true),
    ),
  );
}
```

### Failure handling yaxshilash

**Eski kod:**
```dart
final result = snapshot.data?.fold(
  (failure) {
    _showSnackBar('Error: ${failure.message}', Colors.red);
    return <Data>[];
  },
  (data) => data,
);
```

**Yangi kod:**
```dart
final result = snapshot.data?.fold(
  (failure) {
    // User-friendly message
    final message = ErrorHandlerService.instance.getErrorMessage(failure);
    ErrorHandlerService.instance.showErrorSnackBar(context, message);
    return <Data>[];
  },
  (data) => data,
);
```

## Keyingi qadamlar

1. **Barcha StreamBuilder'larda error handling yaxshilash**
   - `products_page.dart`
   - `orders_page.dart`
   - `parts_page.dart`
   - `departments_page.dart`
   - `department_details_page.dart`

2. **Network error handling yaxshilash**
   - Internet connectivity tekshirish
   - Retry mechanism qo'shish
   - Offline mode support

3. **Supabase error handling yaxshilash**
   - RLS policy xatoliklarini yaxshiroq handle qilish
   - Permission xatoliklarini user-friendly qilish

4. **Error logging yaxshilash**
   - Sentry yoki boshqa logging service integratsiya qilish
   - Production'da error tracking

## Test qilish

1. **Network error test:**
   - Internet'ni o'chirib, app'ni ishlatish
   - Xatolik to'g'ri ko'rsatilishi kerak

2. **Permission error test:**
   - Worker role bilan boss funksiyalarini ishlatish
   - Xatolik to'g'ri ko'rsatilishi kerak

3. **Database error test:**
   - Noto'g'ri ma'lumot yuborish
   - Xatolik to'g'ri ko'rsatilishi kerak

## Eslatmalar

- Barcha xatoliklar endi global error handler orqali catch qilinadi
- User-friendly error messages foydalanuvchilar uchun tushunarli
- Error logging production'da debugging uchun yordam beradi
- StreamBuilder'larda error handling yaxshilash kerak (qo'llanma bo'yicha)
















