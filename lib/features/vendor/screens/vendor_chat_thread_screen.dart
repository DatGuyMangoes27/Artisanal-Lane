import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../chat/utils/live_chat_messages.dart';
import '../../chat/widgets/chat_widgets.dart';
import '../providers/vendor_providers.dart';

class VendorChatThreadScreen extends ConsumerStatefulWidget {
  final String threadId;

  const VendorChatThreadScreen({super.key, required this.threadId});

  @override
  ConsumerState<VendorChatThreadScreen> createState() =>
      _VendorChatThreadScreenState();
}

class _VendorChatThreadScreenState
    extends ConsumerState<VendorChatThreadScreen> {
  final _messageController = TextEditingController();
  final List<ChatMessage> _localMessages = [];
  ChatAttachment? _pendingAttachment;
  bool _isSending = false;
  String? _lastMarkedMessageId;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'txt',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.path == null) {
      _showSnack(
        'That file could not be attached on this device.',
        isError: true,
      );
      return;
    }

    const maxBytes = 10 * 1024 * 1024;
    if (file.size > maxBytes) {
      _showSnack('Attachments must be smaller than 10 MB.', isError: true);
      return;
    }

    setState(() {
      _pendingAttachment = ChatAttachment(
        path: file.path,
        name: file.name,
        mimeType: _guessMimeType(file.extension),
        sizeBytes: file.size,
      );
    });
  }

  Future<void> _sendMessage(String userId, ChatThread thread) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    setState(() => _isSending = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      ChatAttachment? attachment = _pendingAttachment;

      if (attachment?.path != null) {
        attachment = await service.uploadChatAttachment(
          thread.id,
          File(attachment!.path!),
        );
      }

      final sentMessage = await service.sendChatMessage(
        threadId: thread.id,
        senderId: userId,
        body: text.isEmpty ? null : text,
        attachment: attachment,
      );

      _messageController.clear();
      if (mounted) {
        setState(() {
          _pendingAttachment = null;
          _localMessages.add(sentMessage);
        });
      }

      ref.invalidate(vendorThreadsProvider);
      ref.invalidate(vendorChatThreadProvider(widget.threadId));
    } catch (error) {
      _showSnack('Could not send message: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _markReadIfNeeded(
    List<ChatMessage> messages,
    String userId,
  ) async {
    if (messages.isEmpty) return;
    final latestId = messages.last.id;
    if (_lastMarkedMessageId == latestId) return;

    _lastMarkedMessageId = latestId;
    await ref
        .read(supabaseServiceProvider)
        .markThreadRead(widget.threadId, userId);
    ref.invalidate(vendorThreadsProvider);
    ref.invalidate(vendorChatThreadProvider(widget.threadId));
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? AppTheme.error : AppTheme.baobab,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final threadAsync = ref.watch(vendorChatThreadProvider(widget.threadId));
    final messagesAsync = ref.watch(
      vendorThreadMessagesProvider(widget.threadId),
    );
    final displayedMessagesAsync = messagesAsync.whenData(
      (messages) => buildDisplayedChatMessages(
        streamedMessages: messages,
        localMessages: _localMessages,
      ),
    );
    final messages = displayedMessagesAsync.value;

    if (userId != null && messages != null && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markReadIfNeeded(messages, userId);
      });
    }

    return threadAsync.when(
      data: (thread) {
        final isAdminThread = thread.kind.isAdminVendor;
        final title = isAdminThread
            ? 'Artisan Lane Support'
            : (thread.buyerDisplayName ?? 'Buyer');
        final subtitle = isAdminThread
            ? 'Platform team'
            : thread.shopName;
        final avatarUrl = isAdminThread ? null : thread.buyerAvatarUrl;
        final avatarFallback = isAdminThread
            ? 'A'
            : (thread.buyerDisplayName ?? 'B');
        return ChatThreadScaffold(
          messagesAsync: displayedMessagesAsync,
          currentUserId: userId ?? '',
          title: title,
          subtitle: subtitle,
          avatarUrl: avatarUrl,
          avatarFallback: avatarFallback,
          composer: _ChatComposer(
            controller: _messageController,
            pendingAttachment: _pendingAttachment,
            isSending: _isSending,
            onAttach: _pickAttachment,
            onRemoveAttachment: () => setState(() => _pendingAttachment = null),
            onSend: userId == null ? null : () => _sendMessage(userId, thread),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(backgroundColor: AppTheme.scaffoldBg),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load this conversation.\n$error',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final ChatAttachment? pendingAttachment;
  final bool isSending;
  final VoidCallback onAttach;
  final VoidCallback onRemoveAttachment;
  final VoidCallback? onSend;

  const _ChatComposer({
    required this.controller,
    required this.pendingAttachment,
    required this.isSending,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingAttachment != null)
              PendingChatAttachmentCard(
                attachment: pendingAttachment!,
                onRemove: onRemoveAttachment,
              ),
            Row(
              children: [
                IconButton(
                  onPressed: isSending ? null : onAttach,
                  icon: const Icon(Icons.attach_file_rounded),
                  color: AppTheme.terracotta,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textHint,
                      ),
                      filled: true,
                      fillColor: AppTheme.scaffoldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: isSending ? null : onSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.terracotta,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String? _guessMimeType(String? extension) {
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
