class ChatAttachment {
  final String? url;
  final String? path;
  final String name;
  final String? mimeType;
  final int? sizeBytes;

  const ChatAttachment({
    this.url,
    this.path,
    required this.name,
    this.mimeType,
    this.sizeBytes,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      url: json['attachment_url'] as String?,
      path: json['attachment_path'] as String?,
      name: json['attachment_name'] as String? ?? 'Attachment',
      mimeType: json['attachment_mime'] as String?,
      sizeBytes: (json['attachment_size_bytes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'attachment_url': url,
        'attachment_path': path,
        'attachment_name': name,
        'attachment_mime': mimeType,
        'attachment_size_bytes': sizeBytes,
      };

  ChatAttachment copyWith({
    String? url,
    String? path,
    String? name,
    String? mimeType,
    int? sizeBytes,
  }) {
    return ChatAttachment(
      url: url ?? this.url,
      path: path ?? this.path,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isVideo => mimeType?.startsWith('video/') ?? false;
}
