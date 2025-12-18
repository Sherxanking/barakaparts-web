/// ImageService - Rasmlar bilan ishlash uchun service
/// 
/// Bu service rasmlarni saqlash, o'qish va o'chirish funksiyalarini boshqaradi.
/// Rasmlar app documents directory da saqlanadi va Supabase Storage'ga yuklanadi.
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

class ImageService {
  /// App documents directory
  static Future<Directory> get _documentsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, 'part_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Rasmni saqlash
  /// 
  /// [imageFile] - tanlangan rasm fayli
  /// [partId] - qism ID si (fayl nomi uchun)
  /// 
  /// Qaytaradi: Supabase Storage'dagi rasm URL'i yoki local path (agar yuklash muvaffaqiyatsiz bo'lsa)
  static Future<String?> saveImage(File imageFile, String partId) async {
    try {
      final extension = path.extension(imageFile.path);
      final fileName = '$partId$extension';
      
      // 1. Supabase Storage'ga yuklash
      try {
        final supabase = Supabase.instance.client;
        final storagePath = 'part_images/$fileName';
        
        debugPrint('📤 Uploading image to Supabase Storage: $storagePath');
        await supabase.storage
            .from('images')
            .upload(
              storagePath,
              imageFile,
              fileOptions: const FileOptions(
                upsert: true, // Agar mavjud bo'lsa, yangilash
              ),
            );
        
        // Public URL olish
        final publicUrl = supabase.storage
            .from('images')
            .getPublicUrl(storagePath);
        
        debugPrint('✅ Image uploaded to Supabase: $publicUrl');
        
        // 2. Local'ga ham saqlash (offline support uchun)
        try {
          final imagesDir = await _documentsDirectory;
          await imageFile.copy(path.join(imagesDir.path, fileName));
        } catch (e) {
          debugPrint('⚠️ Failed to save image locally: $e');
        }
        
        // Supabase Storage URL'ini qaytarish
        return publicUrl;
      } catch (e) {
        debugPrint('❌ Failed to upload image to Supabase: $e');
        // Supabase'ga yuklash muvaffaqiyatsiz bo'lsa, local'ga saqlash
        final imagesDir = await _documentsDirectory;
        final savedFile = await imageFile.copy(
          path.join(imagesDir.path, fileName),
        );
        debugPrint('⚠️ Image saved locally only: ${savedFile.path}');
        return savedFile.path;
      }
    } catch (e) {
      debugPrint('❌ Error saving image: $e');
      return null;
    }
  }

  /// Rasmni o'qish
  /// 
  /// [imagePath] - rasm fayl yo'li yoki Supabase Storage URL'i
  /// 
  /// Qaytaradi: File yoki null (agar Supabase URL bo'lsa, null qaytaradi - NetworkImage ishlatish kerak)
  static File? getImageFile(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    
    // FIX: Agar Supabase Storage URL bo'lsa, null qaytarish (NetworkImage ishlatish kerak)
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return null; // NetworkImage ishlatish kerak
    }
    
    // Local file path bo'lsa
    final file = File(imagePath);
    if (file.existsSync()) {
      return file;
    }
    return null;
  }
  
  /// Rasm URL'ini olish (Supabase Storage yoki local)
  /// 
  /// [imagePath] - rasm fayl yo'li yoki Supabase Storage URL'i
  /// 
  /// Qaytaradi: NetworkImage uchun URL yoki FileImage uchun File
  static dynamic getImageProvider(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    
    // FIX: Agar Supabase Storage URL bo'lsa, NetworkImage qaytarish
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }
    
    // Local file path bo'lsa
    final file = File(imagePath);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  /// Rasmni o'chirish
  /// 
  /// [imagePath] - o'chiriladigan rasm fayl yo'li yoki Supabase Storage URL'i
  static Future<bool> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    
    try {
      // FIX: Agar Supabase Storage URL bo'lsa, Supabase'dan o'chirish
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        try {
          final supabase = Supabase.instance.client;
          // URL'dan storage path'ni olish
          final uri = Uri.parse(imagePath);
          final pathSegments = uri.pathSegments;
          // 'images' bucket'idan keyin kelgan path'ni olish
          final storagePathIndex = pathSegments.indexOf('images');
          if (storagePathIndex != -1 && pathSegments.length > storagePathIndex + 1) {
            final storagePath = pathSegments.sublist(storagePathIndex + 1).join('/');
            debugPrint('🗑️ Deleting image from Supabase Storage: $storagePath');
            await supabase.storage
                .from('images')
                .remove([storagePath]);
            debugPrint('✅ Image deleted from Supabase Storage');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to delete image from Supabase: $e');
        }
      }
      
      // Local file'ni ham o'chirish
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete local image: $e');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Eski rasmlarni tozalash (ixtiyoriy)
  /// 
  /// Bu funksiya mavjud bo'lmagan qismlarga tegishli rasmlarni o'chiradi
  static Future<void> cleanupOrphanedImages(List<String> validPartIds) async {
    try {
      final imagesDir = await _documentsDirectory;
      final files = imagesDir.listSync();
      
      for (var file in files) {
        if (file is File) {
          final fileName = path.basenameWithoutExtension(file.path);
          // Agar fayl nomi valid part ID ga mos kelmasa, o'chirish
          if (!validPartIds.contains(fileName)) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      // Xato bo'lsa, e'tiborsiz qoldirish
    }
  }
}

