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
import '../../disputes/utils/dispute_attachment_support.dart';
import '../providers/vendor_providers.dart';

class VendorDisputeScreen extends ConsumerStatefulWidget {
  final String orderId;

  const VendorDisputeScreen({super.key, required this.orderId});

  @override
  ConsumerState<VendorDisputeScreen> createState() =>
      _VendorDisputeScreenState();
}

class _VendorDisputeScreenState extends ConsumerState<VendorDisputeScreen> {
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
      allowedExtensions: disputeAttachmentAllowedExtensions,
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
    if (file.size > disputeAttachmentMaxBytes) {
      _showSnack('Attachments must be smaller than 50 MB.', isError: true);
      return;
    }
    setState(() {
      _pendingAttachment = ChatAttachment(
        path: file.path,
        name: file.name,
        mimeType: disputeAttachmentMimeTypeForExtension(file.extension),
        sizeBytes: file.size,
      );
    });
  }

  Future<void> _sendDisputeMessage(
    String userId,
    DisputeCase disputeCase,
  ) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;

    setState(() => _isSending = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      ChatAttachment? attachment = _pendingAttachment;
      if (attachment?.path != null) {
        attachment = await service.uploadDisputeAttachment(
          disputeCase.conversationId,
          File(attachment!.path!),
        );
      }
      final sentMessage = await service.sendDisputeMessage(
        conversationId: disputeCase.conversationId,
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
    } catch (error) {
      _showSnack('Could not send message: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _markReadIfNeeded(
    DisputeCase disputeCase,
    List<ChatMessage> messages,
    String userId,
  ) async {
    if (messages.isEmpty) return;
    final latestId = messages.last.id;
    if (_lastMarkedMessageId == latestId) return;
    _lastMarkedMessageId = latestId;
    await ref
        .read(supabaseServiceProvider)
        .markDisputeConversationRead(disputeCase.conversationId, userId);
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
    final disputeAsync = ref.watch(
      vendorActiveDisputeStreamProvider(widget.orderId),
    );
    final userId = ref.watch(currentUserIdProvider);

    return disputeAsync.when(
      data: (disputeCase) {
        if (disputeCase == null) {
          return Scaffold(
            backgroundColor: AppTheme.scaffoldBg,
            appBar: AppBar(backgroundColor: AppTheme.scaffoldBg),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'There is no active dispute conversation for this order yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                ),
              ),
            ),
          );
        }

        final messagesAsync = ref.watch(
          vendorDisputeMessagesProvider(disputeCase.conversationId),
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
            _markReadIfNeeded(disputeCase, messages, userId);
          });
        }

        return ChatThreadScaffold(
          messagesAsync: displayedMessagesAsync,
          currentUserId: userId ?? '',
          title:
              'Order #${widget.orderId.substring(0, 8).toUpperCase()} Dispute',
          subtitle: 'Buyer, seller, and admin case chat',
          avatarFallback: 'D',
          senderLabelResolver: (senderId) =>
              disputeCase.participantFor(senderId)?.label,
          composer: _VendorDisputeComposer(
            controller: _messageController,
            pendingAttachment: _pendingAttachment,
            isSending: _isSending,
            onAttach: _pickAttachment,
            onRemoveAttachment: () => setState(() => _pendingAttachment = null),
            onSend: userId == null
                ? null
                : () => _sendDisputeMessage(userId, disputeCase),
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
              'Could not load this dispute.\n$error',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorDisputeComposer extends StatelessWidget {
  final TextEditingController controller;
  final ChatAttachment? pendingAttachment;
  final bool isSending;
  final VoidCallback onAttach;
  final VoidCallback onRemoveAttachment;
  final VoidCallback? onSend;

  const _VendorDisputeComposer({
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
        decoration: const BoxDecoration(color: Colors.white),
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
                      hintText: 'Reply in the dispute conversation...',
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
