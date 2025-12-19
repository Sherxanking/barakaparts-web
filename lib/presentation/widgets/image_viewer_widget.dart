/// ImageViewerWidget - Rasmni katta ko'rinishda ko'rsatish va tahrirlash uchun widget
/// 
/// Bu widget rasmni katta ko'rinishda ko'rsatadi va tahrirlash imkoniyatini beradi.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';

class ImageViewerWidget extends StatelessWidget {
  /// Rasm fayl yo'li
  final String? imagePath;
  
  /// Rasm o'zgartirilganda chaqiriladigan callback
  final Function(File?) onImageChanged;
  
  /// Rasm o'chirilganda chaqiriladigan callback
  final VoidCallback? onImageDeleted;

  const ImageViewerWidget({
    super.key,
    this.imagePath,
    required this.onImageChanged,
    this.onImageDeleted,
  });

  /// Rasm tanlash dialogini ko'rsatish
  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final l10n = AppLocalizations.of(context);
    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.translate('selectImageSource') ?? 'Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 32),
              title: Text(l10n?.translate('camera') ?? 'Camera'),
              subtitle: Text(l10n?.translate('takeNewPhoto') ?? 'Take a new photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 32),
              title: Text(l10n?.translate('gallery') ?? 'Gallery'),
              subtitle: Text(l10n?.translate('chooseFromGallery') ?? 'Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        final pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null) {
          onImageChanged(File(pickedFile.path));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error picking image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final imageFile = hasImage ? File(imagePath!) : null;
    final imageExists = imageFile != null && imageFile.existsSync();

    return GestureDetector(
      onTap: () => _showImageDialog(context),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: imageExists
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      imageFile!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder(context);
                      },
                    ),
                    // Overlay - bosilganda ko'rsatish
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showImageDialog(context),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _buildPlaceholder(context),
      ),
    );
  }

  /// Rasm dialogini ko'rsatish (katta ko'rinish)
  void _showImageDialog(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final imageFile = hasImage ? File(imagePath!) : null;
    final imageExists = imageFile != null && imageFile.existsSync();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Katta rasm
            if (imageExists)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  imageFile!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 300,
                      color: Colors.grey[800],
                      child: const Icon(Icons.broken_image, size: 64, color: Colors.white),
                    );
                  },
                ),
              )
            else
              Container(
                width: 300,
                height: 300,
                color: Colors.grey[800],
                child: const Icon(Icons.image, size: 64, color: Colors.white),
              ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Change image button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(context);
                  },
                  icon: const Icon(Icons.image),
                  label: const Text('Change'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                // Delete button (faqat rasm bo'lsa)
                if (imageExists)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onImageChanged(null);
                      onImageDeleted?.call();
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(width: 8),
                // Close button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.translate('tapToAddImage') ?? 'Tap to add image',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

