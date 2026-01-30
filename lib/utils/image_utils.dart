import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// Image utility functions
class ImageUtils {
  ImageUtils._(); // Private constructor

  /// Resmi optimize et ve sıkıştır
  static Future<File?> compressImage(File imageFile) async {
    try {
      final filePath = imageFile.absolute.path;
      final lastModified = await imageFile.lastModified();
      final targetPath = '${path.dirname(filePath)}/compressed_${path.basename(filePath)}';

      // Resmi sıkıştır
      final result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        quality: AppConstants.imageQuality,
        minWidth: AppConstants.maxImageWidth,
        minHeight: AppConstants.maxImageHeight,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        final originalSize = await imageFile.length();
        final compressedSize = await compressedFile.length();
        
        AppLogger.performance(
          'Image compression',
          Duration.zero, // Compression time ölçülmüyor şimdilik
          context: {
            'original_size_kb': (originalSize / 1024).toStringAsFixed(2),
            'compressed_size_kb': (compressedSize / 1024).toStringAsFixed(2),
            'compression_ratio': ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1),
          },
        );

        return compressedFile;
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Image compression failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Dosya boyutunu kontrol et
  static bool isValidFileSize(File file, {int maxSizeMB = AppConstants.maxImageSizeMB}) {
    final sizeInBytes = file.lengthSync();
    final sizeInMB = sizeInBytes / (1024 * 1024);
    return sizeInMB <= maxSizeMB;
  }

  /// Dosya tipini kontrol et
  static bool isValidImageType(String filePath) {
    final extension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
    return AppConstants.supportedImageTypes.contains(extension);
  }

  /// Dosya adını temizle (güvenlik için)
  static String sanitizeFileName(String fileName) {
    // Tehlikeli karakterleri kaldır
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, fileName.length > 100 ? 100 : fileName.length);
  }

  /// Unique dosya adı oluştur
  static String generateUniqueFileName(String originalFileName, String userId) {
    final sanitized = sanitizeFileName(originalFileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sanitized);
    final nameWithoutExt = path.basenameWithoutExtension(sanitized);
    return '${userId}_${timestamp}_$nameWithoutExt$extension';
  }
}
