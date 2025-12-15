# Realtime Sync Fix - Products va Orders

## 🔴 MUAMMO
- Telefondan part qo'shildi, lekin Chromedan ko'rinmadi
- Yangi product yaratildi, lekin boshqa joyda ko'rinmadi
- Order yaratildi, lekin boshqa login qilingan joyda o'zgarmadi

## ✅ YECHIM

### QADAM 1: Supabase'da Realtime Yoqish

Supabase Dashboard → SQL Editor'da quyidagi SQL'ni ishga tushiring:

```sql
-- Enable realtime for products
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE products;
  END IF;
END $$;

-- Enable realtime for orders
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE orders;
  END IF;
END $$;
```

Yoki `supabase/migrations/023_enable_realtime_products_orders.sql` faylini ishga tushiring.

### QADAM 2: App'da Stream'lar Ishga Tushirish

`main.dart`'da stream'lar ishga tushirish kerak. Repository'lar allaqachon stream'lar ishlatmoqda va cache'ni yangilayapti, lekin stream'lar ishga tushirilmagan.

**Yechim:** `main.dart`'da `_initializeServicesInBackground()` funksiyasiga stream'lar ishga tushirish qo'shish kerak.

### QADAM 3: Test Qilish

1. Supabase'da realtime yoqish (QADAM 1)
2. App'ni qayta ishga tushiring
3. Telefondan part/product/order qo'shing
4. Chromedan tekshiring - endi ko'rinishi kerak!

