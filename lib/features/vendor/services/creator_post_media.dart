import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const creatorPostMediaBucket = 'creator-post-media';
const _markerScheme = 'artisan-post';
const creatorPostVideoMaxBytes = 50 * 1024 * 1024;
const creatorPostVideoMaxDuration = Duration(seconds: 60);

bool isCreatorPostMediaMarker(String value) =>
    Uri.tryParse(value)?.scheme.toLowerCase() == _markerScheme;

String? creatorPostMediaPath(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != _markerScheme || uri.host.isEmpty) {
    return null;
  }
  final path = uri.pathSegments.where((part) => part.isNotEmpty).join('/');
  if (!RegExp(
    r'^[0-9a-f-]{36}/[0-9a-f-]{36}\.(mp4|mov)$',
    caseSensitive: false,
  ).hasMatch('${uri.host}/$path')) {
    return null;
  }
  return '${uri.host}/$path';
}

String creatorPostMediaMarker(String path) => '$_markerScheme://$path';

class CreatorPostMediaRepository {
  CreatorPostMediaRepository(this._client);
  final SupabaseClient _client;

  Future<String> uploadVideo({
    required String ownerId,
    required File file,
    required String uploadId,
  }) async {
    void checkAccount() {
      if (_client.auth.currentUser?.id != ownerId) {
        throw StateError('Your account changed. Reopen the editor.');
      }
    }
    checkAccount();
    if (await file.length() > creatorPostVideoMaxBytes) {
      throw StateError('Post videos must be 50 MB or smaller.');
    }
    final lowerPath = file.path.toLowerCase();
    if (!lowerPath.endsWith('.mp4') && !lowerPath.endsWith('.mov')) {
      throw StateError('Post videos must be MP4 or MOV files.');
    }
    final extension = lowerPath.endsWith('.mov') ? 'mov' : 'mp4';
    final path = '$ownerId/$uploadId.$extension';
    checkAccount();
    try {
      await _client.storage
          .from(creatorPostMediaBucket)
          .upload(
            path,
            file,
            fileOptions: FileOptions(
              contentType: extension == 'mov' ? 'video/quicktime' : 'video/mp4',
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      if (error.statusCode != '409') rethrow;
    }
    checkAccount();
    return creatorPostMediaMarker(path);
  }

  /// Storage SELECT RLS re-checks ownership/publication before signing.
  Future<String?> signedUrlFor(String marker, {int expiresIn = 300}) async {
    final userId = _client.auth.currentUser?.id;
    final path = creatorPostMediaPath(marker);
    if (path == null) return null;
    try {
      final url = await _client.storage
          .from(creatorPostMediaBucket)
          .createSignedUrl(path, expiresIn);
      return _client.auth.currentUser?.id == userId ? url : null;
    } on StorageException {
      return null;
    }
  }

  String newUploadId() => const Uuid().v4();
}
