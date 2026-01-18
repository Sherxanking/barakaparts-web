========================================
SUPABASE MIGRATIONS - QO'LLANMA
========================================

⚠️ MUHIM ESLATMA:
- SUPABASE_MIGRATIONS_MINIMAL.md - faqat dokumentatsiya, SQL emas!
- Faqat .sql fayllarni Supabase SQL Editor'da ishga tushiring!

========================================
ISHGA TUSHIRISH TARTIBI:
========================================

1. 1000_mvp_stabilization.sql
   - Barcha jadvallar, RLS, realtime
   - updated_at xatolik tuzatilgan ✅

2. 1001_prevent_duplicate_names.sql
   - Duplicate prevention
   - Unique indexes

3. 1002_add_users_trigger.sql (Ixtiyoriy)
   - Auth userlar avtomatik yaratilishi

========================================
XATOLIKLAR:
========================================

❌ "syntax error at or near #"
   - Markdown faylini SQL sifatida ishga tushirmang!
   - Faqat .sql fayllarni ishga tushiring!

❌ "column updated_at does not exist"
   - 1000_mvp_stabilization.sql ni qayta ishga tushiring
   - Xatolik tuzatilgan ✅

========================================























