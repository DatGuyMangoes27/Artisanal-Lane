import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// One of the listing's photos, as handed to Listing Studio. The studio only
/// reads it; edits come back as new bytes tagged with [id] so the product
/// form can swap that photo in place.
class StudioPhotoSource {
  const StudioPhotoSource({
    required this.id,
    required this.thumbnail,
    required this.loadBytes,
  });

  /// Stable id of the photo in the product form (null for a photo picked
  /// inside the studio, which is added as a new photo).
  final String? id;
  final ImageProvider thumbnail;
  final Future<Uint8List> Function() loadBytes;

  factory StudioPhotoSource.file(String? id, File file) => StudioPhotoSource(
    id: id,
    thumbnail: FileImage(file),
    loadBytes: file.readAsBytes,
  );
}

/// Downloads an already-uploaded listing photo so it can be touched up.
Future<Uint8List> loadNetworkPhotoBytes(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Photo download failed', uri: Uri.parse(url));
    }
    return await consolidateHttpClientResponseBytes(response);
  } finally {
    client.close(force: true);
  }
}

/// Where an edited studio photo lands in a listing's photo list: replacing
/// the photo it was made from (keeping its position, so a touched-up cover
/// stays the cover), or appended when it has no source in the list.
/// Returns null when appending would exceed [maxPhotos].
List<T>? placeStudioPhoto<T>(
  List<T> photos, {
  required T edited,
  required bool Function(T photo) isSource,
  int maxPhotos = 8,
}) {
  final index = photos.indexWhere(isSource);
  if (index >= 0) {
    return [...photos]..[index] = edited;
  }
  if (photos.length >= maxPhotos) return null;
  return [...photos, edited];
}
