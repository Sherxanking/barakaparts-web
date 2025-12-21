#!/bin/bash
# Package Nomini O'zgartirish Script
# 
# Foydalanish:
# 1. Script'ni executable qiling: chmod +x package_rename_script.sh
# 2. Ishga tushiring: ./package_rename_script.sh
#
# Yoki qo'lda bajarish:
# bash package_rename_script.sh

# ============================================
# SOZLAMALAR
# ============================================

# Hozirgi package nomi
OLD_PACKAGE="com.example.parts_control"

# Yangi package nomi (o'zgartiring!)
NEW_PACKAGE="com.barakaparts.app"

# ============================================
# TEKSHIRISH
# ============================================

echo "⚠️  Eslatma: Backup oling!"
echo "Hozirgi package: $OLD_PACKAGE"
echo "Yangi package: $NEW_PACKAGE"
echo ""
read -p "Davom etishni xohlaysizmi? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Bekor qilindi."
    exit 1
fi

# ============================================
# ANDROID: build.gradle.kts
# ============================================

echo "📝 Android build.gradle.kts o'zgartirilmoqda..."
sed -i "s/namespace = \"$OLD_PACKAGE\"/namespace = \"$NEW_PACKAGE\"/g" android/app/build.gradle.kts
sed -i "s/applicationId = \"$OLD_PACKAGE\"/applicationId = \"$NEW_PACKAGE\"/g" android/app/build.gradle.kts
echo "✅ Android build.gradle.kts yangilandi"

# ============================================
# ANDROID: Kotlin faylini ko'chirish
# ============================================

echo "📁 Kotlin faylini ko'chirish..."

# Eski va yangi papkalar
OLD_DIR="android/app/src/main/kotlin/$(echo $OLD_PACKAGE | tr '.' '/')"
NEW_DIR="android/app/src/main/kotlin/$(echo $NEW_PACKAGE | tr '.' '/')"

# Yangi papka yaratish
mkdir -p "$NEW_DIR"

# Faylni ko'chirish
if [ -f "$OLD_DIR/MainActivity.kt" ]; then
    cp "$OLD_DIR/MainActivity.kt" "$NEW_DIR/MainActivity.kt"
    echo "✅ MainActivity.kt ko'chirildi"
    
    # Package nomini o'zgartirish
    sed -i "s/package $OLD_PACKAGE/package $NEW_PACKAGE/g" "$NEW_DIR/MainActivity.kt"
    echo "✅ MainActivity.kt ichidagi package nomi yangilandi"
    
    # Eski faylni o'chirish
    rm -rf "$OLD_DIR"
    echo "✅ Eski papka o'chirildi"
else
    echo "⚠️  MainActivity.kt topilmadi: $OLD_DIR/MainActivity.kt"
fi

# ============================================
# iOS: Info.plist
# ============================================

echo "📝 iOS Info.plist o'zgartirilmoqda..."
if [ -f "ios/Runner/Info.plist" ]; then
    # macOS/Linux uchun
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/<string>$OLD_PACKAGE<\/string>/<string>$NEW_PACKAGE<\/string>/g" ios/Runner/Info.plist
    else
        sed -i "s/<string>$OLD_PACKAGE<\/string>/<string>$NEW_PACKAGE<\/string>/g" ios/Runner/Info.plist
    fi
    echo "✅ iOS Info.plist yangilandi"
else
    echo "⚠️  Info.plist topilmadi"
fi

# ============================================
# FLUTTER: app_constants.dart
# ============================================

echo "📝 Flutter constants o'zgartirilmoqda..."
# Deep link URL'ni o'zgartirish
OLD_DEEPLINK="com.barakaparts://login-callback"
NEW_DEEPLINK="$NEW_PACKAGE://login-callback"

if [ -f "lib/core/constants/app_constants.dart" ]; then
    sed -i "s|return '$OLD_DEEPLINK'|return '$NEW_DEEPLINK'|g" lib/core/constants/app_constants.dart
    echo "✅ app_constants.dart yangilandi"
else
    echo "⚠️  app_constants.dart topilmadi"
fi

# ============================================
# YAKUN
# ============================================

echo ""
echo "✅ Package nomi o'zgartirildi!"
echo ""
echo "📋 Keyingi qadamlar:"
echo "1. AndroidManifest.xml'ga deep link qo'shing (agar kerak bo'lsa)"
echo "2. Supabase Dashboard'da OAuth redirect URL'ni yangilang"
echo "3. Google Cloud Console'da redirect URI'ni yangilang"
echo "4. flutter clean && flutter pub get"
echo "5. Test qiling"
echo ""
echo "Yangi package nomi: $NEW_PACKAGE"



















