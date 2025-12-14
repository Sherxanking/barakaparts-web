# 🔧 Login Xatolik Yechimi

## ❌ "Failed to sign in" Xatolik

### Sabablar va Yechimlar:

### 1. .env Fayl Muammosi
**Xatolik**: `SUPABASE_URL` yoki `SUPABASE_ANON_KEY` topilmadi

**Yechim**:
1. `.env` fayl yaratilganini tekshiring
2. `.env` fayl ichida quyidagilar bo'lishi kerak:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your_anon_key_here
   ```

### 2. User Authentication da Yo'q
**Xatolik**: "Invalid login credentials"

**Yechim**:
1. Supabase Dashboard → Authentication → Users
2. User yaratilganini tekshiring
3. Email va Password to'g'ri ekanligini tekshiring

### 3. Users Jadvalida Yo'q
**Xatolik**: "User data not found in users table"

**Yechim**:
1. Authentication da user yaratilgan bo'lishi kerak
2. Users jadvaliga qo'shish kerak:

```sql
-- User ID ni Authentication → Users dan oling
INSERT INTO users (id, name, email, role) VALUES
  ('USER_ID_BU_YERGA', 'User Name', 'user@example.com', 'worker');
```

### 4. Internet Aloqasi
**Xatolik**: "Network error" yoki "Connection failed"

**Yechim**:
- Internet aloqasini tekshiring
- Supabase project faol ekanligini tekshiring

## 🔍 Debug Qilish

Console da quyidagi xabarlarni tekshiring:

```
✅ Supabase initialized successfully (ANON key)
🔍 Current user: null
📱 User login qilmagan - LoginPage ochiladi
```

Login qilishda:
```
❌ Login xatolik: [xatolik matni]
```

## ✅ To'g'ri Sozlash

1. **.env fayl yaratish**:
   ```bash
   cp .env.example .env
   ```

2. **.env faylni to'ldirish**:
   - Supabase Dashboard → Settings → API
   - URL va ANON key ni oling

3. **User yaratish**:
   - Authentication → Users → Add user
   - SQL Editor da users jadvaliga qo'shing

4. **Test qilish**:
   - App ni qayta run qiling
   - Login qiling




