# ✅ Default Role'ni Manager Qilish (Vaqtinchalik)

**Muammo:** Worker role bilan muammo bor

**Yechim:** Hozircha barcha userlar uchun default role 'manager' qilish

---

## 🔧 YECHIM

### STEP 1: SQL Migration'ni Qo'llash

**Fayl:** `SET_DEFAULT_ROLE_MANAGER.sql`

**Qadamlari:**
1. **Supabase Dashboard** → **SQL Editor**
2. `SET_DEFAULT_ROLE_MANAGER.sql` faylini oching
3. Barcha SQL kodini nusxalab, SQL Editor'ga yopishtiring
4. **RUN** tugmasini bosing

**Bu migration:**
- ✅ Mavjud userlarni yangilaydi (worker -> manager)
- ✅ Trigger'ni yangilaydi (default role 'manager')
- ✅ Default value 'manager' o'rnatadi
- ✅ Test accountlarni saqlab qoladi (boss@test.com, manager@test.com)

---

## 📊 KUTILGAN NATIJA

Migration'dan keyin:

```
========================================
ROLE STATISTICS:
========================================
✅ Manager users: X
⚠️ Worker users: 0 (yoki kam)
✅ Boss users: 1 (boss@test.com)
📊 Total users: X
========================================
✅ Default role set to MANAGER (TEMPORARY)
✅ Trigger updated - new users will get MANAGER role
✅ Test accounts (boss@test.com, manager@test.com) unchanged
```

---

## 🧪 TEKSHIRISH

### Query 1: Role Distribution

```sql
SELECT role, COUNT(*) as count
FROM public.users
GROUP BY role
ORDER BY role;
```

**Kutilgan natija:**
- `boss`: 1 (boss@test.com)
- `manager`: X (barcha boshqa userlar)

---

### Query 2: Test Accounts

```sql
SELECT id, email, role 
FROM public.users 
WHERE email IN ('boss@test.com', 'manager@test.com');
```

**Kutilgan natija:**
- `boss@test.com` → role: `boss`
- `manager@test.com` → role: `manager`

---

## ⚠️ MUHIM ESLATMA

Bu **vaqtinchalik** o'zgarish. Keyin worker role'ni qo'shamiz va default role'ni 'worker' qilamiz.

Hozircha:
- ✅ Barcha yangi userlar 'manager' role bilan yaratiladi
- ✅ Mavjud worker userlar 'manager' ga o'zgartirildi
- ✅ Test accountlar o'zgarishsiz qoldi

---

## 📝 KEYINGI QADAMLAR

1. Manager role bilan test qilish
2. Muammolarni aniqlash
3. Keyin worker role'ni qo'shish
4. Default role'ni 'worker' qilish

---

## ✅ XULOSA

**Endi:** Barcha userlar 'manager' role bilan ishlaydi. Test accountlar o'zgarishsiz qoldi.

Migration'ni bajarib, natijalarni yuboring! 🎉








