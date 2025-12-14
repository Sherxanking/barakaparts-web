# 🌐 Internet Aloqasi Muammosi - Yechim

## ❌ Xatolik: "Failed host lookup"

### Sabab:
Internet aloqasi yo'q yoki Supabase serverga ulanib bo'lmayapti.

## ✅ Yechimlar:

### 1. Internet Aloqasini Tekshiring

**Android Device:**
- Settings → Wi-Fi yoki Mobile Data
- Internet faol ekanligini tekshiring
- Browser da biror sayt ochib ko'ring

**Emulator:**
- Emulator Settings → Network
- Internet aloqasi yoqilganini tekshiring
- Emulator ni qayta ishga tushiring

### 2. Supabase URL ni Tekshiring

`.env` faylda `SUPABASE_URL` to'g'ri ekanligini tekshiring:

```env
SUPABASE_URL=https://tnwdodhgdrzpucbkhfpg.supabase.co
```

**Tekshirish:**
1. Browser da URL ni ochib ko'ring
2. Supabase Dashboard ochilishi kerak
3. Agar ochilmasa, URL noto'g'ri

### 3. Firewall yoki VPN

- Firewall Supabase ga kirishni bloklayotgan bo'lishi mumkin
- VPN ishlatayotgan bo'lsangiz, o'chirib ko'ring

### 4. Supabase Project Faolmi?

1. Supabase Dashboard ga kiring
2. Project faol ekanligini tekshiring
3. Project pause qilingan bo'lishi mumkin

## 🔍 Tekshirish:

### Terminal da:

```powershell
# Supabase URL ni tekshirish
Test-NetConnection -ComputerName tnwdodhgdrzpucbkhfpg.supabase.co -Port 443
```

Agar "TcpTestSucceeded: False" bo'lsa, internet aloqasi yo'q.

### Browser da:

```
https://tnwdodhgdrzpucbkhfpg.supabase.co
```

Agar ochilmasa, URL noto'g'ri yoki project pause qilingan.

## 🎯 Keyingi Qadamlar:

1. ✅ Internet aloqasini tekshiring
2. ✅ Supabase URL ni tekshiring
3. ✅ App ni qayta run qiling
4. ✅ Login qilib ko'ring

---

**Agar hali ham muammo bo'lsa:**
- Internet aloqasi faolmi?
- Supabase Dashboard ochiladimi?
- Device/Emulator internetga ulanmaganmi?




