# 🎯 STEP 1: Supabase Auth + Rollar Tuzilmasi

## 📋 Nima Qurayapmiz?

1. Supabase Authentication sozlash
2. Users jadvali yaratish (Boss, Manager, Worker rollari bilan)
3. RLS (Row Level Security) policy larni sozlash
4. Flutter da Auth service yaratish
5. Role-based access control

---

## 🧭 Qadam 1: Supabase Database Schema

### 📁 Fayl: `supabase/migrations/001_auth_and_users.sql`

**Menga topshiriq:**

```sql
-- ============================================
-- 1. USERS JADVALI
-- ============================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('boss', 'manager', 'worker')),
  department_id UUID REFERENCES departments(id), -- Manager uchun
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexlar
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_department ON users(department_id);

-- RLS yoqish
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. RLS POLICY LAR
-- ============================================

-- Policy 1: Har bir user o'z ma'lumotlarini ko'ra oladi
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);

-- Policy 2: Boss barcha userlarni ko'ra oladi
CREATE POLICY "Boss can read all users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'boss'
    )
  );

-- Policy 3: Manager o'z bo'limidagi userlarni ko'ra oladi
CREATE POLICY "Manager can read department users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users u1
      WHERE u1.id = auth.uid() 
      AND u1.role = 'manager'
      AND u1.department_id = users.department_id
    )
  );

-- Policy 4: User o'zini yaratishi mumkin (signup paytida)
CREATE POLICY "Users can insert own data" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Policy 5: Boss userlarni yangilashi mumkin
CREATE POLICY "Boss can update users" ON users
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'boss'
    )
  );

-- ============================================
-- 3. FUNCTION: Auto-create user on signup
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'worker')::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Auth user yaratilganda users jadvaliga qo'shish
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 4. DEPARTMENTS JADVALI (Manager uchun)
-- ============================================
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- Barcha authenticated userlar ko'ra oladi
CREATE POLICY "Authenticated users can read departments" ON departments
  FOR SELECT USING (auth.role() = 'authenticated');
```

**Qayerda:** Supabase Dashboard → SQL Editor → New Query

---

## 🧭 Qadam 2: Flutter Folder Structure

### 📁 Folder Struktura:

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── errors/
│   │   └── failures.dart
│   └── utils/
│       └── either.dart
├── domain/
│   ├── entities/
│   │   └── user.dart
│   └── repositories/
│       └── auth_repository.dart
├── infrastructure/
│   ├── datasources/
│   │   └── supabase_auth_datasource.dart
│   └── repositories/
│       └── auth_repository_impl.dart
├── presentation/
│   ├── features/
│   │   └── auth/
│   │       ├── providers/
│   │       │   └── auth_provider.dart
│   │       ├── pages/
│   │       │   ├── login_page.dart
│   │       │   └── signup_page.dart
│   │       └── widgets/
│   │           └── role_selector_widget.dart
└── main.dart
```

---

## 🧭 Qadam 3: Domain Layer

### 📁 Fayl: `lib/domain/entities/user.dart`

**Menga topshiriq:**

```dart
class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'boss', 'manager', 'worker'
  final String? departmentId; // Manager uchun
  
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.departmentId,
  });
  
  bool get isBoss => role == 'boss';
  bool get isManager => role == 'manager';
  bool get isWorker => role == 'worker';
}
```

---

### 📁 Fayl: `lib/domain/repositories/auth_repository.dart`

**Menga topshiriq:**

```dart
import '../entities/user.dart';
import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> signIn(String email, String password);
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? departmentId,
  });
  Future<Either<Failure, void>> signOut();
  Future<Either<Failure, User?>> getCurrentUser();
  Stream<User?> watchAuthState();
}
```

---

## 🧭 Qadam 4: Infrastructure Layer

### 📁 Fayl: `lib/infrastructure/datasources/supabase_auth_datasource.dart`

**Menga topshiriq:**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/user.dart';
import '../../../core/utils/either.dart';
import '../../../core/errors/failures.dart';

class SupabaseAuthDatasource {
  final SupabaseClient _client = Supabase.instance.client;
  
  Future<Either<Failure, User>> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user == null) {
        return Left(AuthFailure('Login failed'));
      }
      
      // Users jadvalidan user ma'lumotlarini olish
      final userData = await _client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();
      
      return Right(_mapToUser(userData));
    } catch (e) {
      return Left(AuthFailure('Login error: $e'));
    }
  }
  
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? departmentId,
  }) async {
    try {
      // 1. Auth user yaratish
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
          if (departmentId != null) 'department_id': departmentId,
        },
      );
      
      if (response.user == null) {
        return Left(AuthFailure('Signup failed'));
      }
      
      // 2. Trigger orqali users jadvaliga avtomatik qo'shiladi
      // 3. Users jadvalidan olish
      final userData = await _client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();
      
      return Right(_mapToUser(userData));
    } catch (e) {
      return Left(AuthFailure('Signup error: $e'));
    }
  }
  
  Future<Either<Failure, void>> signOut() async {
    try {
      await _client.auth.signOut();
      return Right(null);
    } catch (e) {
      return Left(AuthFailure('Logout error: $e'));
    }
  }
  
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return Right(null);
      
      final userData = await _client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();
      
      return Right(_mapToUser(userData));
    } catch (e) {
      return Right(null);
    }
  }
  
  Stream<User?> watchAuthState() {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      
      // Users jadvalidan olish (async, lekin stream da)
      return _client
          .from('users')
          .select()
          .eq('id', user.id)
          .single()
          .then((data) => _mapToUser(data))
          .catchError((_) => null);
    }).asyncMap((future) => future);
  }
  
  User _mapToUser(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      departmentId: json['department_id'] as String?,
    );
  }
}
```

---

## 🧭 Qadam 5: Repository Implementation

### 📁 Fayl: `lib/infrastructure/repositories/auth_repository_impl.dart`

**Menga topshiriq:**

```dart
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../datasources/supabase_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDatasource _datasource;
  
  AuthRepositoryImpl(this._datasource);
  
  @override
  Future<Either<Failure, User>> signIn(String email, String password) {
    return _datasource.signIn(email, password);
  }
  
  @override
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? departmentId,
  }) {
    return _datasource.signUp(
      email: email,
      password: password,
      name: name,
      role: role,
      departmentId: departmentId,
    );
  }
  
  @override
  Future<Either<Failure, void>> signOut() {
    return _datasource.signOut();
  }
  
  @override
  Future<Either<Failure, User?>> getCurrentUser() {
    return _datasource.getCurrentUser();
  }
  
  @override
  Stream<User?> watchAuthState() {
    return _datasource.watchAuthState();
  }
}
```

---

## 🧭 Qadam 6: Riverpod Provider

### 📁 Fayl: `lib/presentation/features/auth/providers/auth_provider.dart`

**Menga topshiriq:**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../domain/entities/user.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../../infrastructure/datasources/supabase_auth_datasource.dart';
import '../../../../infrastructure/repositories/auth_repository_impl.dart';

part 'auth_provider.g.dart';

// Repository provider
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(SupabaseAuthDatasource());
}

// Current user provider
@riverpod
Stream<User?> currentUser(CurrentUserRef ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.watchAuthState();
}

// Auth state provider (loading, error, user)
@riverpod
class AuthState extends _$AuthState {
  @override
  Future<User?> build() async {
    final repository = ref.watch(authRepositoryProvider);
    final result = await repository.getCurrentUser();
    return result.fold(
      (failure) => null,
      (user) => user,
    );
  }
  
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.signIn(email, password);
    
    state = result.fold(
      (failure) => AsyncValue.error(failure, StackTrace.current),
      (user) => AsyncValue.data(user),
    );
  }
  
  Future<void> signOut() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.signOut();
    state = const AsyncValue.data(null);
  }
}
```

**Eslatma:** `build_runner` ishlatish kerak:
```bash
flutter pub run build_runner build
```

---

## 📌 Menga Topshiriq:

1. ✅ SQL migration faylini yaratish va Supabase da bajarish
2. ✅ Folder strukturasini yaratish
3. ✅ Domain entities va repositories yozish
4. ✅ Infrastructure datasource va repository impl yozish
5. ✅ Riverpod provider yozish
6. ✅ `pubspec.yaml` ga `riverpod_annotation` va `riverpod_generator` qo'shish

---

## ⏳ Kutish:

"Bajardim" deb yozing, keyin STEP 2 ga o'tamiz.

---

## ⚠️ Xatolarni Oldini Olish:

- ❌ `service_role` key frontend da ishlatilmaydi
- ✅ Faqat `anon` key ishlatiladi
- ✅ RLS policy lar to'g'ri sozlangan
- ✅ Trigger orqali avtomatik user yaratiladi

---

## 🏆 Motivatsiya:

**XP: +100** 🎮  
**Progress: STEP 1/7 (14%)** 📊  
**Keyingi:** STEP 2 - Parts Database + Real-time

---

**Bajardim deb yozing!** 🚀




