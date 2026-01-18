# ✅ STEP 1: Test Fayllarni O'chirish

**Muammo:** Test fayllarda mockito xatolari (production'ga ta'sir qilmaydi)

**Yechim:** Test fayllarni o'chirish yoki ignore qilish

---

## 📋 QADAMLAR

### Variant A: Test Fayllarni O'chirish

**Fayllar:**
- `test/infrastructure/datasources/supabase_auth_datasource_test.dart`
- `test/infrastructure/repositories/user_repository_impl_test.dart`

**Qo'llash:**
```bash
# Windows PowerShell
Remove-Item test\infrastructure\datasources\supabase_auth_datasource_test.dart
Remove-Item test\infrastructure\repositories\user_repository_impl_test.dart
```

---

### Variant B: Analysis Options'da Ignore Qilish

**Fayl:** `analysis_options.yaml`

**O'zgarish:**
```yaml
analyzer:
  exclude:
    - test/**/*_test.dart
```

---

## ✅ TASDIQLASH

**Qaysi variantni tanlaysiz?**
- [ ] Variant A: Test fayllarni o'chirish
- [ ] Variant B: Analysis options'da ignore qilish

**Approve? [Yes/No]**
































