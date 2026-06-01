Uri? normalizeTrackingUri(String? value) {
  return trackingUriLaunchCandidates(value).firstOrNull;
}

List<Uri> trackingUriLaunchCandidates(String? value) {
  if (value == null) return const [];

  final trimmed = value.trim();
  if (trimmed.isEmpty) return const [];

  if (trimmed.contains('://')) {
    final uri = _validWebUri(trimmed);
    return uri == null ? const [] : [uri];
  }

  return [
    _validWebUri('https://$trimmed'),
    _validWebUri('http://$trimmed'),
  ].whereType<Uri>().toList(growable: false);
}

Uri? _validWebUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;

  return uri;
}
