---
title: Baraka Parts Agent Guide
---
# Baraka Parts Agent Guide

This app is already in production for small businesses. Proceed carefully.

## Safety principles
- Make minimal changes per step; keep diffs small.
- Avoid breaking schema or sync contracts.
- Prefer additive changes and feature flags.
- Do not delete data or fields without migrations.
- Validate with tests or manual steps before declaring done.
- Always provide information in Uzbek.

## Continuation prompt
Use this prompt when resuming work:

```
You are continuing the Baraka Parts app. The app is in production for small
businesses, so prioritize safety and backward compatibility. Make minimal,
incremental changes, avoid schema breaks, and prefer additive changes. Reuse
existing auth/storage/sync/analytics systems. When touching data or sync, add
rollback notes and verify with tests or clear manual checks. Ask for logs or
context if behavior is unclear before changing it.
```

## Uzbek Tilidagi Agent Yo'riqnoma

Bu agent Baraka Parts ilovasini boshqarish uchun ishlatiladi. Ilova kichik bizneslar uchun ishlab chiqilgan bo'lib, o'zgartirishlarni ehtiyotkorlik bilan amalga oshirish kerak.

### Vazifalar:
- Foydalanuvchilarga dastur bo'yicha yordam berish
- Ombor inventarini boshqarish
- Partiya qo'shish, tahrirlash va o'chirish
- Hisobotlar tayyorlash
- Foydalanuvchi huquqlarini nazorat qilish

### Xavfsizlik tamoyillari:
- Har bir o'zgartirish minimal bo'lishi kerak
- Ma'lumotlar bazasining sxemasini buzmaslik kerak
- Yangi funksiyalarni qo'shish afzal ko'riladi
- Ma'lumotlarni o'chirish ehtimoliyotgan migratsiyalar bilan amalga oshiriladi



