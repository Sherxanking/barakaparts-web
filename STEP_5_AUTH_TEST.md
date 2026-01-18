# ✅ STEP 5: Authentication Flow Test

**Muammo:** Login flow to'g'ri ishlashini tekshirish

**Yechim:** Har bir login flow'ni test qilish

---

## 📋 TEST QADAMLARI

### Test 1: Email/Password Login (Boss)

**Qadamlari:**
1. App'ni oching
2. Email: `boss@test.com`
3. Password: `Boss123!`
4. Login tugmasini bosing

**Kutilgan natija:**
- ✅ Home page'ga o'tish
- ✅ Role = 'boss'
- ✅ Admin panel ko'rinadi

---

### Test 2: Email/Password Login (Manager)

**Qadamlari:**
1. Logout qiling
2. Email: `manager@test.com`
3. Password: `Manager123!`
4. Login tugmasini bosing

**Kutilgan natija:**
- ✅ Home page'ga o'tish
- ✅ Role = 'manager'
- ✅ Parts yaratish mumkin

---

### Test 3: Google Login

**Qadamlari:**
1. Logout qiling
2. "Sign in with Google" tugmasini bosing
3. Google account tanlang
4. Ruxsat bering

**Kutilgan natija:**
- ✅ Home page'ga o'tish
- ✅ Role = 'manager'
- ✅ Parts yaratish mumkin

---

### Test 4: Session Persistence

**Qadamlari:**
1. Login qiling
2. App'ni to'liq yoping (kill app)
3. App'ni qayta oching

**Kutilgan natija:**
- ✅ Avtomatik login
- ✅ Home page ko'rinadi
- ✅ Session saqlanadi

---

### Test 5: Logout

**Qadamlari:**
1. Login qiling
2. Logout tugmasini bosing

**Kutilgan natija:**
- ✅ Login page'ga qaytish
- ✅ Session tozalanadi

---

## ✅ TASDIQLASH

**Approve? [Yes/No]**
































