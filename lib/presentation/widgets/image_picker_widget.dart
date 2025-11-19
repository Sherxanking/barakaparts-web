/// ImagePickerWidget - Rasm tanlash va ko'rsatish uchun widget
/// 
/// Bu widget rasm tanlash, ko'rsatish va o'chirish funksiyalarini ta'minlaydi.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerWidget extends StatelessWidget {
  /// Hozirgi rasm fayl yo'li
  final String? currentImagePath;
  
  /// Rasm tanlanganda chaqiriladigan callback
  final Function(File?) onImagePicked;
  
  /// Rasm o'chirilganda chaqiriladigan callback
  final VoidCallback? onImageDeleted;

  const ImagePickerWidget({
    super.key,
    this.currentImagePath,
    required this.onImagePicked,
    this.onImageDeleted,
  });

  /// Rasm tanlash dialogini ko'rsatish
  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
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
          onImagePicked(File(pickedFile.path));
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
    final hasImage = currentImagePath != null && currentImagePath!.isNotEmpty;
    final imageFile = hasImage ? File(currentImagePath!) : null;
    final imageExists = imageFile != null && imageFile.existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rasm ko'rsatish
        GestureDetector(
          onTap: () => _pickImage(context),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: imageExists
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      imageFile!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder(context);
                      },
                    ),
                  )
                : _buildPlaceholder(context),
          ),
        ),
        const SizedBox(height: 8),
        // Buttonlar
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(context),
                icon: const Icon(Icons.image),
                label: Text(hasImage ? 'Change Image' : 'Pick Image'),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  onImagePicked(null);
                  onImageDeleted?.call();
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Remove Image',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add image',
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

