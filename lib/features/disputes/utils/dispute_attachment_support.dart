const disputeAttachmentMaxBytes = 50 * 1024 * 1024;

const disputeAttachmentAllowedExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'mp4',
  'mov',
  'webm',
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'txt',
];

String? disputeAttachmentMimeTypeForExtension(String? extension) {
  switch ((extension ?? '').toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'txt':
      return 'text/plain';
    default:
      return null;
  }
}
