import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../chat/utils/live_chat_messages.dart';
import '../../chat/widgets/chat_widgets.dart';
import '../../disputes/utils/dispute_attachment_support.dart';
import '../providers/buyer_providers.dart';

class BuyerDisputeScreen extends ConsumerStatefulWidget {
  final String orderId;

  const BuyerDisputeScreen({super.key, required this.orderId});

  @override
  ConsumerState<BuyerDisputeScreen> createState() => _BuyerDisputeScreenState();
}

class _BuyerDisputeScreenState extends ConsumerState<BuyerDisputeScreen> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  final _descriptionFocusNode = FocusNode();
  final _messageController = TextEditingController();
  final List<ChatMessage> _localMessages = [];
  ChatAttachment? _pendingAttachment;
  bool _isSending = false;
  bool _isOpeningDispute = false;
  String? _lastMarkedMessageId;
  DisputeCase? _openedDispute;

  final _reasons = const [
    'Item not received',
    'Item arrived damaged',
    'Item not as described',
    'Wrong item received',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _descriptionFocusNode.unfocus();
    FocusScope.of(context).unfocus();
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

  Future<DisputeCase?> _waitForDisputeCase(String userId) async {
    final service = ref.read(supabaseServiceProvider);
    for (var attempt = 0; attempt < 6; attempt++) {
      final disputeCase = await service.getActiveDisputeForOrder(
        widget.orderId,
        userId,
      );
      if (disputeCase != null) {
        return disputeCase;
      }
      if (attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return null;
  }

  Future<void> _submitDispute() async {
    final selectedReason = _selectedReason;
    if (selectedReason == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack(
        'Please sign in again before opening a dispute.',
        isError: true,
      );
      return;
    }
    _dismissKeyboard();
    try {
      setState(() => _isOpeningDispute = true);
      final service = ref.read(supabaseServiceProvider);
      final description = _descriptionController.text.trim();
      final fullReason = description.isNotEmpty
          ? '$selectedReason: $description'
          : selectedReason;
      await service.createDispute(widget.orderId, userId, fullReason);
      final disputeCase = await _waitForDisputeCase(userId);
      ref.invalidate(ordersProvider);
      ref.invalidate(ordersStreamProvider);
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(orderDetailStreamProvider(widget.orderId));
      ref.invalidate(buyerActiveDisputeProvider(widget.orderId));
      ref.invalidate(buyerActiveDisputeStreamProvider(widget.orderId));
      if (disputeCase != null) {
        ref.invalidate(
          buyerDisputeMessagesProvider(disputeCase.conversationId),
        );
      }
      if (mounted) {
        setState(() => _openedDispute = disputeCase);
      }
      _showSnack('Dispute opened. The case conversation is now available.');
    } catch (error) {
      _showSnack('Could not open dispute: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isOpeningDispute = false);
      }
    }
  }

  void _showConfirmDialog() {
    _dismissKeyboard();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Submit Dispute?',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'This will put the order into dispute and open a case chat with the seller and our admin team.',
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: AppTheme.textSecondary,
            height: 1.6,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isOpeningDispute
                ? null
                : () async {
                    _dismissKeyboard();
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    await _submitDispute();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disputeAsync = ref.watch(
      buyerActiveDisputeStreamProvider(widget.orderId),
    );
    final disputeOnceAsync = ref.watch(
      buyerActiveDisputeProvider(widget.orderId),
    );
    final activeDispute =
        disputeAsync.value ?? disputeOnceAsync.value ?? _openedDispute;
    final userId = ref.watch(currentUserIdProvider);
    if (activeDispute != null &&
        (activeDispute.status == 'open' ||
            activeDispute.status == 'investigating' ||
            activeDispute.status == 'resolved')) {
      final messagesAsync = ref.watch(
        buyerDisputeMessagesProvider(activeDispute.conversationId),
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
          _markReadIfNeeded(activeDispute, messages, userId);
        });
      }

      return ChatThreadScaffold(
        messagesAsync: displayedMessagesAsync,
        currentUserId: userId ?? '',
        title: 'Order #${widget.orderId.substring(0, 8).toUpperCase()} Dispute',
        subtitle: 'Buyer, seller, and admin case chat',
        avatarFallback: 'D',
        senderLabelResolver: (senderId) =>
            activeDispute.participantFor(senderId)?.label,
        composer: _DisputeComposer(
          controller: _messageController,
          pendingAttachment: _pendingAttachment,
          isSending: _isSending,
          onAttach: _pickAttachment,
          onRemoveAttachment: () => setState(() => _pendingAttachment = null),
          onSend: userId == null
              ? null
              : () => _sendDisputeMessage(userId, activeDispute),
        ),
      );
    }

    if (_isOpeningDispute ||
        (disputeAsync.isLoading && disputeOnceAsync.isLoading)) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
      );
    }

    final disputeError = disputeAsync.error ?? disputeOnceAsync.error;
    if (disputeError != null) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(backgroundColor: AppTheme.scaffoldBg),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load this dispute.\n$disputeError',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.sand.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Raise a Dispute',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.ochre.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.ochre.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'Opening a dispute will put the order under review and start a case conversation with the seller and our admin team.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.ochre,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'What went wrong?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ..._reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return GestureDetector(
                  onTap: () => setState(() => _selectedReason = reason),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.terracotta.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.terracotta
                            : AppTheme.sand.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? AppTheme.terracotta
                              : AppTheme.textHint,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            reason,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppTheme.terracotta
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              TextField(
                controller: _descriptionController,
                focusNode: _descriptionFocusNode,
                maxLines: 5,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Give the admin team and the seller the key details you want them to review.',
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedReason == null || _isOpeningDispute
                      ? null
                      : _showConfirmDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isOpeningDispute
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Dispute'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisputeComposer extends StatelessWidget {
  final TextEditingController controller;
  final ChatAttachment? pendingAttachment;
  final bool isSending;
  final VoidCallback onAttach;
  final VoidCallback onRemoveAttachment;
  final VoidCallback? onSend;

  const _DisputeComposer({
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
                      hintText: 'Add to the dispute conversation...',
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
