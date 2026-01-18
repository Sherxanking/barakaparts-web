# 🔐 Keystore Yaratish Qo'llanmasi

## ⚠️ MUHIM: Parollarni Eslab Qoling!

Keystore yaratishda kiritilgan parollarni **MUTLAQ eslab qoling** yoki xavfsiz joyga yozib qo'ying!

Agar parolni unutsangiz yoki keystore'ni yo'qotib qo'ysangiz, app'ni yangilay olmaysiz!

---

## 📝 Keystore Yaratish

### Qadam 1: Buyruqni Bajaring

PowerShell'da quyidagi buyruqni bajaring:

```powershell
cd E:\BarakaParts\android\app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Qadam 2: Ma'lumotlarni Kiriting

Keytool sizdan quyidagi ma'lumotlarni so'raydi:

1. **Enter keystore password**: 
   - Parol yozing (masalan: `BarakaParts2024!`)
   - ⚠️ Bu parolni eslab qoling!

2. **Re-enter new password**: 
   - Xuddi shu parolni qayta kiriting

3. **What is your first and last name?**
   - Ismingiz yoki kompaniya nomi (masalan: `BarakaParts`)

4. **What is the name of your organizational unit?**
   - Bo'lim nomi (ixtiyoriy, Enter bosib o'tkazishingiz mumkin)

5. **What is the name of your organization?**
   - Kompaniya nomi (masalan: `BarakaParts`)

6. **What is the name of your City or Locality?**
   - Shahar (masalan: `Tashkent`)

7. **What is the name of your State or Province?**
   - Viloyat (masalan: `Tashkent Region`)

8. **What is the two-letter country code for this unit?**
   - Mamlakat kodi: `UZ`

9. **Is CN=BarakaParts, OU=Unknown, O=BarakaParts, L=Tashkent, ST=Tashkent Region, C=UZ correct?**
   - `yes` yozing

10. **Enter key password for <upload>**:
    - Key paroli (odatda keystore paroli bilan bir xil)
    - Agar bir xil bo'lishini xohlasangiz, Enter bosib o'tkazishingiz mumkin

---

## ✅ Keystore Yaratilgandan Keyin

Keystore yaratilgandan keyin, quyidagi fayl yaratiladi:
- `android/app/upload-keystore.jks`

---

## 📝 key.properties Yaratish

Keystore yaratilgandan keyin, `android/key.properties` faylini yarating:

```properties
storePassword=SIZNING_KEYSTORE_PAROLINGIZ
keyPassword=SIZNING_KEY_PAROLINGIZ
keyAlias=upload
storeFile=app/upload-keystore.jks
```

**O'zgartirishlar**:
- `SIZNING_KEYSTORE_PAROLINGIZ` → Keystore parolingiz (1-qadamda kiritgan parol)
- `SIZNING_KEY_PAROLINGIZ` → Key parolingiz (10-qadamda kiritgan parol, odatda keystore paroli bilan bir xil)

---

## 🚀 Keyingi Qadamlar

1. ✅ Keystore yaratildi
2. ✅ `key.properties` yaratildi
3. ✅ Release build qilish: `flutter build appbundle --release`
4. ✅ Google Play Console'ga yuklash

---

## ⚠️ XAVFSIZLIK

- ✅ Keystore parolini **hech kimga bermang**!
- ✅ Keystore faylini **backup qiling** (xavfsiz joyga)
- ✅ Parollarni **password manager**'da saqlang
- ✅ `key.properties` va `upload-keystore.jks` **Git'ga commit qilinmaydi** (`.gitignore`'da mavjud)

---

## 📞 Yordam

Agar muammo bo'lsa:
1. Parollarni tekshiring
2. Keystore fayli yaratilganligini tekshiring
3. `key.properties` faylini tekshiring


