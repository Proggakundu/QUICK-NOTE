import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class CameraService {
  final ImagePicker _picker = ImagePicker();

  Future<ImageResult?> takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        if (kIsWeb) {
          // For web: return bytes
          final bytes = await photo.readAsBytes();
          return ImageResult(bytes: bytes, path: photo.name);
        } else {
          // For mobile: return file path
          return ImageResult(path: photo.path);
        }
      }
      return null;
    } catch (e) {
      print('Error taking picture: $e');
      return null;
    }
  }

  Future<ImageResult?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          // For web: return bytes
          final bytes = await image.readAsBytes();
          return ImageResult(bytes: bytes, path: image.name);
        } else {
          // For mobile: return file path
          return ImageResult(path: image.path);
        }
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }
}

class ImageResult {
  final String path;
  final Uint8List? bytes;

  ImageResult({required this.path, this.bytes});
}