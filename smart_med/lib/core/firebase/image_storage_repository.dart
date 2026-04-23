import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_med/core/firebase/storage_paths.dart';

class ImageStorageRepositoryException implements Exception {
  const ImageStorageRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImageStorageRepository {
  ImageStorageRepository({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadProfileImage({
    required String uid,
    required XFile image,
  }) {
    final extension = _normalizedExtension(image.name, image.path);

    return _uploadImage(
      image: image,
      path: StoragePaths.profileImage(uid: uid, extension: extension),
      contentType: _contentTypeForExtension(extension),
    );
  }

  Future<String> uploadMedicationImage({
    required String uid,
    required String medicationId,
    required XFile image,
  }) {
    final extension = _normalizedExtension(image.name, image.path);

    return _uploadImage(
      image: image,
      path: StoragePaths.medicationImage(
        uid: uid,
        medicationId: medicationId,
        extension: extension,
      ),
      contentType: _contentTypeForExtension(extension),
    );
  }

  Future<String> _uploadImage({
    required XFile image,
    required String path,
    required String contentType,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      final reference = _storage.ref(path);

      await reference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      return reference.getDownloadURL();
    } on FirebaseException catch (e) {
      throw ImageStorageRepositoryException(
        _storageError('upload the image to Firebase Storage', e),
      );
    }
  }

  String _storageError(String action, FirebaseException exception) {
    final code = exception.code.trim();
    if (code.isEmpty) {
      return 'Failed to $action.';
    }

    return 'Failed to $action (${exception.code}).';
  }

  String _normalizedExtension(String fileName, String path) {
    final candidates = [fileName, path];

    for (final candidate in candidates) {
      final normalized = candidate.trim().toLowerCase();
      final lastDot = normalized.lastIndexOf('.');

      if (lastDot == -1 || lastDot == normalized.length - 1) {
        continue;
      }

      final extension = normalized.substring(lastDot + 1);
      if (_supportedExtensions.contains(extension)) {
        return extension;
      }
    }

    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  static const Set<String> _supportedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  };
}

final ImageStorageRepository imageStorageRepository = ImageStorageRepository();
