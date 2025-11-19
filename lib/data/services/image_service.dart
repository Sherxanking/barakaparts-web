/// ImageService - Rasmlar bilan ishlash uchun service
/// 
/// Bu service rasmlarni saqlash, o'qish va o'chirish funksiyalarini boshqaradi.
/// Rasmlar app documents directory da saqlanadi.
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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
  /// Qaytaradi: saqlangan rasm fayl yo'li
  static Future<String?> saveImage(File imageFile, String partId) async {
    try {
      final imagesDir = await _documentsDirectory;
      final extension = path.extension(imageFile.path);
      final fileName = '$partId$extension';
      final savedFile = await imageFile.copy(
        path.join(imagesDir.path, fileName),
      );
      return savedFile.path;
    } catch (e) {
      return null;
    }
  }

  /// Rasmni o'qish
  /// 
  /// [imagePath] - rasm fayl yo'li
  /// 
  /// Qaytaradi: File yoki null
  static File? getImageFile(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    final file = File(imagePath);
    if (file.existsSync()) {
      return file;
    }
    return null;
  }

  /// Rasmni o'chirish
  /// 
  /// [imagePath] - o'chiriladigan rasm fayl yo'li
  static Future<bool> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      // Xato bo'lsa, e'tiborsiz qoldirish
    }
    return false;
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

