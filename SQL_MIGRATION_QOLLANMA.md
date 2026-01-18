# 🚀 SQL Migration Bajarish - Qo'llanma

## ⏱️ Vaqt: 5-10 daqiqa

## 📋 QADAMLAR

### 1. Supabase Dashboard'ga Kirish

1. [Supabase Dashboard](https://app.supabase.com) ga kiring
2. Loyihangizni tanlang
3. Chap menudan **SQL Editor** ni tanlang

---

### 2. Migration Faylini O'qish

**Fayl:** `supabase/migrations/1000_mvp_stabilization.sql`

Bu fayl:
- ✅ Barcha RLS policies'ni to'g'ri sozlaydi
- ✅ Users table'ni xavfsiz qiladi
- ✅ Indexes qo'shadi (performance uchun)
- ✅ Realtime'ni yoqadi
- ✅ Barcha jadvallar uchun policies yaratadi

---

### 3. SQL'ni Bajarish

1. **SQL Editor** da **New Query** tugmasini bosing
2. `1000_mvp_stabilization.sql` faylini oching
3. **Barcha SQL kodini** nusxalab (Ctrl+A, Ctrl+C)
4. SQL Editor'ga yopishtiring (Ctrl+V)
5. **RUN** tugmasini bosing (yoki F5)

---

### 4. Kutilgan Natija

Migration muvaffaqiyatli bajarilsa, quyidagilar ko'rinadi:

```
✅ Users table already exists
✅ Name column added
✅ Email column added
✅ Role column added
...
✅ MVP stabilization complete!
```

**Xatolik bo'lsa:**
- Xatolik xabari ko'rinadi
- Xatolikni ko'rsating, yechamiz

---

### 5. Tekshirish (Optional)

Migration'dan keyin quyidagi SQL'ni bajarib tekshirishingiz mumkin:

```sql
-- RLS yoqilganligini tekshirish
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'parts', 'products', 'orders', 'departments');

-- Policies sonini tekshirish
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename;
```

**Kutilgan natija:**
- Barcha jadvallarda `rowsecurity = true`
- Har bir jadvalda 3-6 ta policy bo'lishi kerak

---

## ✅ Migration Bajarilgandan Keyin

1. ✅ RLS policies ishlaydi
2. ✅ Boss va Manager create/update/delete qila oladi
3. ✅ Worker faqat o'qiy oladi
4. ✅ Realtime yangilanishlar ishlaydi
5. ✅ Performance yaxshilandi (indexes qo'shildi)

---

## ⚠️ MUHIM ESLATMA

- Bu migration **xavfsiz** - mavjud ma'lumotlarni o'zgartirmaydi
- Faqat policies va strukturalarni sozlaydi
- Agar xatolik bo'lsa, xabar ko'rsating

---

## 🆘 Yordam

Agar muammo bo'lsa:
1. Xatolik xabari nima?
2. Qaysi qadamda xatolik bo'ldi?
3. Screenshot yuborsangiz yaxshi bo'ladi

















