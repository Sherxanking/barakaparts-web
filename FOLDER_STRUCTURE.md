# 📁 Folder Structure - Clean Architecture + Feature-First

## 🏗️ Umumiy Struktura

```
lib/
├── core/                           # Core utilities (framework-independent)
│   ├── api/                        # API client (backend API uchun)
│   │   └── api_client.dart        # Dio-based API client
│   ├── config/                     # Configuration
│   │   └── env_config.dart        # Environment variables (.env)
│   ├── errors/                     # Error handling
│   │   └── failures.dart          # Failure classes
│   ├── utils/                      # Utilities
│   │   ├── either.dart            # Either type
│   │   └── constants.dart         # App constants
│   └── di/                         # Dependency Injection
│       └── service_locator.dart   # Service locator
│
├── domain/                         # Business Logic Layer
│   ├── entities/                   # Pure Dart entities
│   │   ├── user.dart
│   │   ├── part.dart
│   │   ├── product.dart
│   │   ├── order.dart
│   │   ├── department.dart
│   │   └── log.dart
│   ├── repositories/               # Repository interfaces
│   │   ├── user_repository.dart
│   │   ├── part_repository.dart
│   │   ├── product_repository.dart
│   │   ├── order_repository.dart
│   │   ├── department_repository.dart
│   │   └── log_repository.dart
│   └── permissions/                # Permission logic
│       └── user_permissions.dart
│
├── infrastructure/                  # External Concerns
│   ├── datasources/                 # Data sources
│   │   ├── supabase_client.dart   # Supabase client (ANON key only!)
│   │   ├── supabase_part_datasource.dart
│   │   ├── supabase_product_datasource.dart
│   │   ├── supabase_order_datasource.dart
│   │   └── supabase_department_datasource.dart
│   ├── cache/                       # Local cache (Hive)
│   │   ├── hive_part_cache.dart
│   │   ├── hive_product_cache.dart
│   │   └── ...
│   ├── models/                       # Hive models
│   │   ├── hive_part_model.dart
│   │   └── ...
│   └── repositories/                # Repository implementations
│       ├── part_repository_impl.dart
│       ├── product_repository_impl.dart
│       └── ...
│
├── application/                     # Application Layer (Use Cases)
│   └── services/                    # Application services
│       ├── auth_service.dart        # Authentication (backend API orqali)
│       ├── part_service.dart        # Part operations
│       ├── product_service.dart     # Product operations
│       ├── order_service.dart       # Order operations
│       ├── audit_service.dart       # Audit logging
│       └── analytics_service.dart   # Analytics
│
├── features/                        # Feature-First Structure
│   ├── auth/                        # Authentication feature
│   │   ├── data/                    # Data layer (feature-specific)
│   │   │   ├── datasources/
│   │   │   └── repositories/
│   │   ├── domain/                  # Domain layer (feature-specific)
│   │   │   ├── entities/
│   │   │   └── repositories/
│   │   └── presentation/            # Presentation layer
│   │       ├── pages/
│   │       │   └── login_page.dart
│   │       └── widgets/
│   │
│   ├── parts/                       # Parts feature
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── parts_page.dart
│   │       └── widgets/
│   │
│   ├── products/                    # Products feature
│   │   └── ...
│   │
│   ├── orders/                      # Orders feature
│   │   └── ...
│   │
│   └── departments/                 # Departments feature
│       └── ...
│
├── presentation/                    # Shared Presentation Layer
│   ├── pages/                       # Shared pages
│   │   └── home_page.dart
│   ├── widgets/                      # Shared widgets
│   │   ├── search_bar_widget.dart
│   │   ├── loading_widget.dart
│   │   └── ...
│   └── theme/                       # App theme
│       └── app_theme.dart
│
└── data/                            # Legacy data layer (migrate qilinadi)
    ├── models/                      # Hive models (old)
    └── services/                    # Old services (migrate qilinadi)
```

## 🔒 Xavfsizlik Qoidalari

### ✅ Qilish Kerak:
1. **Frontend**: Faqat ANON key ishlatish
2. **.env fayl**: Barcha keys .env faylda
3. **Backend API**: Sensitive operatsiyalar backend orqali
4. **Service Role**: Faqat backend da, environment variable sifatida

### ❌ Qilish MUMKIN EMAS:
1. Service role key frontend da
2. Keys Git repository ga commit qilish
3. Hardcoded keys kodda
4. Sensitive operatsiyalarni to'g'ridan-to'g'ri frontend dan

## 📋 Migration Plan

### Phase 1: Core Setup ✅
- [x] Environment config
- [x] API client
- [x] Supabase client (anon key only)
- [x] Folder structure

### Phase 2: Features Migration
- [ ] Auth feature
- [ ] Parts feature
- [ ] Products feature
- [ ] Orders feature

### Phase 3: Backend API
- [ ] Backend API yaratish
- [ ] Service role key backend da
- [ ] Sensitive operatsiyalar backend ga ko'chirish




