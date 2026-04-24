import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../features/buyer/utils/cart_stock_guard.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _client;

  static const _pendingRequestedRoleKey = 'pending_auth_requested_role';
  static const _pendingDisplayNameKey = 'pending_auth_display_name';
  static const _chatAttachmentBucket = 'chat-attachments';
  static const _disputeAttachmentBucket = 'dispute-attachments';
  static const _chatThreadSelect =
      '*, shops(name, logo_url), buyer:profiles!chat_threads_buyer_id_fkey(display_name, avatar_url), vendor:profiles!chat_threads_vendor_id_fkey(display_name, avatar_url), chat_thread_reads(participant_id, last_read_at, last_read_message_id)';
  static const _shopReviewSelect = '*, profiles(display_name, avatar_url)';
  static const _productReviewSelect = '*, profiles(display_name, avatar_url)';

  SupabaseService(this._client);

  Future<Map<String, String>> _authorizedFunctionHeaders() async {
    final currentSession = _client.auth.currentSession;
    if (currentSession?.refreshToken != null) {
      try {
        final refreshed = await _client.auth.refreshSession();
        final refreshedToken = refreshed.session?.accessToken;
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          return {'Authorization': 'Bearer $refreshedToken'};
        }
      } on AuthException {
        // Fall back to the currently cached session below so callers get a
        // consistent auth error if the refresh token is no longer valid.
      }
    }

    final accessToken = currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException(
        'Your session expired. Please sign in again and retry checkout.',
      );
    }

    return {'Authorization': 'Bearer $accessToken'};
  }

  Future<void> savePendingAuthIntent({
    required String requestedRole,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRequestedRoleKey, requestedRole);

    final trimmedName = displayName?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      await prefs.remove(_pendingDisplayNameKey);
    } else {
      await prefs.setString(_pendingDisplayNameKey, trimmedName);
    }
  }

  Future<void> clearPendingAuthIntent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRequestedRoleKey);
    await prefs.remove(_pendingDisplayNameKey);
  }

  Future<Map<String, String>?> _consumePendingAuthIntent() async {
    final prefs = await SharedPreferences.getInstance();
    final requestedRole = prefs.getString(_pendingRequestedRoleKey);
    final displayName = prefs.getString(_pendingDisplayNameKey);

    await prefs.remove(_pendingRequestedRoleKey);
    await prefs.remove(_pendingDisplayNameKey);

    if (requestedRole == null && displayName == null) {
      return null;
    }

    return {
      if (requestedRole != null) 'requested_role': requestedRole,
      if (displayName != null) 'display_name': displayName,
    };
  }

  Future<AuthResponse> signInWithGoogleNative({
    String? requestedRole,
    String? displayName,
  }) async {
    final normalizedRole = requestedRole == 'vendor' ? 'vendor' : 'buyer';
    final trimmedDisplayName = displayName?.trim();
    final webClientId = AppConstants.googleWebClientId.trim();
    final iosClientId = AppConstants.googleIosClientId.trim();

    if (webClientId.isEmpty) {
      throw Exception(
        'GOOGLE_WEB_CLIENT_ID is not configured. Add it to your Dart defines before using native Google sign-in.',
      );
    }

    if (requestedRole != null || (trimmedDisplayName?.isNotEmpty ?? false)) {
      await savePendingAuthIntent(
        requestedRole: normalizedRole,
        displayName: trimmedDisplayName,
      );
    }

    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(
        serverClientId: webClientId,
        clientId: Platform.isIOS ? iosClientId : null,
      );

      final googleAccount = await signIn.authenticate();
      final googleAuthentication = googleAccount.authentication;
      final idToken = googleAuthentication.idToken;

      if (idToken == null) {
        throw Exception('Google sign-in did not return an ID token.');
      }

      return _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (error) {
      if (requestedRole != null || (trimmedDisplayName?.isNotEmpty ?? false)) {
        await clearPendingAuthIntent();
      }
      rethrow;
    }
  }

  // ── Storage ─────────────────────────────────────────────────
  static String _mimeType(String ext) {
    switch (ext) {
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
        return 'application/octet-stream';
    }
  }

  static String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  static String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  Future<String?> _createSignedAttachmentUrl(
    String bucket,
    String? path,
  ) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage.from(bucket).createSignedUrl(path, 60 * 60);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _createSignedChatAttachmentUrl(String? path) async {
    return _createSignedAttachmentUrl(_chatAttachmentBucket, path);
  }

  Future<String?> _createSignedDisputeAttachmentUrl(String? path) async {
    return _createSignedAttachmentUrl(_disputeAttachmentBucket, path);
  }

  Future<ChatMessage> _hydrateChatMessage(ChatMessage message) async {
    final attachment = message.attachment;
    final path = attachment?.path;
    if (attachment == null || path == null || path.isEmpty) {
      return message;
    }

    final signedUrl =
        attachment.url ?? await _createSignedChatAttachmentUrl(path);
    return message.copyWith(attachment: attachment.copyWith(url: signedUrl));
  }

  Future<ChatMessage> _hydrateDisputeMessage(ChatMessage message) async {
    final attachment = message.attachment;
    final path = attachment?.path;
    if (attachment == null || path == null || path.isEmpty) {
      return message;
    }

    final signedUrl =
        attachment.url ?? await _createSignedDisputeAttachmentUrl(path);
    return message.copyWith(attachment: attachment.copyWith(url: signedUrl));
  }

  Future<int> _getUnreadMessageCountForThread(
    ChatThread thread,
    String currentUserId,
  ) async {
    if (thread.lastMessageAt == null ||
        thread.lastMessageSenderId == currentUserId) {
      return 0;
    }

    if (thread.lastReadAt != null &&
        !thread.lastMessageAt!.isAfter(thread.lastReadAt!)) {
      return 0;
    }

    var query = _client
        .from('chat_messages')
        .select('id')
        .eq('thread_id', thread.id)
        .neq('sender_id', currentUserId);

    if (thread.lastReadAt != null) {
      query = query.gt('created_at', thread.lastReadAt!.toIso8601String());
    }

    final rows = await query;
    return (rows as List).length;
  }

  Future<ChatThread> _hydrateChatThread(
    Map<String, dynamic> row,
    String currentUserId,
  ) async {
    final thread = ChatThread.fromJson(row, currentUserId: currentUserId);
    final unreadCount = await _getUnreadMessageCountForThread(
      thread,
      currentUserId,
    );
    return thread.copyWith(unreadCount: unreadCount);
  }

  Future<List<ChatThread>> _mapChatThreads(
    List<dynamic> rows,
    String currentUserId,
  ) async {
    return Future.wait(
      rows.map(
        (row) => _hydrateChatThread(
          Map<String, dynamic>.from(row as Map),
          currentUserId,
        ),
      ),
    );
  }

  Future<List<ChatThread>> _getChatThreadsForParticipant({
    required String column,
    required String userId,
  }) async {
    final rows = await _client
        .from('chat_threads')
        .select(_chatThreadSelect)
        .eq(column, userId)
        .order('last_message_at', ascending: false)
        .order('created_at', ascending: false);

    return _mapChatThreads(rows as List, userId);
  }

  Future<String> uploadProductImage(String userId, File imageFile) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = '$userId/$fileName';

    await _client.storage
        .from('product-images')
        .upload(
          storagePath,
          imageFile,
          fileOptions: FileOptions(contentType: _mimeType(ext)),
        );

    return _client.storage.from('product-images').getPublicUrl(storagePath);
  }

  Future<String> uploadShopImage(
    String userId,
    File imageFile, {
    String folder = 'general',
  }) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = '$userId/$folder/$fileName';

    await _client.storage
        .from('shop-assets')
        .upload(
          storagePath,
          imageFile,
          fileOptions: FileOptions(contentType: _mimeType(ext)),
        );

    return _client.storage.from('shop-assets').getPublicUrl(storagePath);
  }

  Future<String> uploadVendorApplicationImage(
    String userId,
    File imageFile,
  ) async {
    return uploadShopImage(userId, imageFile, folder: 'vendor-application');
  }

  Future<List<String>> _getEligibleDeliveredOrCompletedOrderIds(
    String buyerId,
  ) async {
    final rows = await _client
        .from('orders')
        .select('id')
        .eq('buyer_id', buyerId)
        .inFilter('status', ['delivered', 'completed'])
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => row['id'] as String)
        .toList(growable: false);
  }

  Future<String?> _getLatestEligibleShopOrderId(
    String buyerId,
    String shopId,
  ) async {
    final rows = await _client
        .from('orders')
        .select('id')
        .eq('buyer_id', buyerId)
        .eq('shop_id', shopId)
        .inFilter('status', ['delivered', 'completed'])
        .order('created_at', ascending: false)
        .limit(1);

    final orderRows = rows as List;
    if (orderRows.isEmpty) {
      return null;
    }
    return orderRows.first['id'] as String;
  }

  Future<Map<String, String>?> _getLatestEligibleProductReviewContext(
    String buyerId,
    String productId,
  ) async {
    final orderIds = await _getEligibleDeliveredOrCompletedOrderIds(buyerId);
    if (orderIds.isEmpty) {
      return null;
    }

    for (final orderId in orderIds) {
      final item = await _client
          .from('order_items')
          .select('id')
          .eq('order_id', orderId)
          .eq('product_id', productId)
          .maybeSingle();

      if (item != null) {
        return {'order_id': orderId, 'order_item_id': item['id'] as String};
      }
    }

    return null;
  }

  Future<ReviewSummary> _getReviewSummary({
    required String table,
    required String column,
    required String value,
  }) async {
    final rows = await _client.from(table).select('rating').eq(column, value);
    final ratings = (rows as List)
        .map((row) => row['rating'] as int)
        .toList(growable: false);
    return ReviewSummary.fromRatings(ratings);
  }

  // ── Chat ───────────────────────────────────────────────────────
  Future<List<ChatThread>> getBuyerThreads(String userId) {
    return _getChatThreadsForParticipant(column: 'buyer_id', userId: userId);
  }

  Future<List<ChatThread>> getVendorThreads(String vendorId) {
    return _getChatThreadsForParticipant(column: 'vendor_id', userId: vendorId);
  }

  Stream<List<ChatThread>> watchBuyerThreads(String userId) {
    return _client
        .from('chat_threads')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', userId)
        .order('last_message_at', ascending: false)
        .asyncMap((_) => getBuyerThreads(userId));
  }

  Stream<List<ChatThread>> watchVendorThreads(String vendorId) {
    return _client
        .from('chat_threads')
        .stream(primaryKey: ['id'])
        .eq('vendor_id', vendorId)
        .order('last_message_at', ascending: false)
        .asyncMap((_) => getVendorThreads(vendorId));
  }

  Future<ChatThread> getThread(String threadId, String currentUserId) async {
    final row = await _client
        .from('chat_threads')
        .select(_chatThreadSelect)
        .eq('id', threadId)
        .single();

    return _hydrateChatThread(Map<String, dynamic>.from(row), currentUserId);
  }

  Future<ChatThread> getOrCreateThread({
    required String shopId,
    required String buyerId,
  }) async {
    final existing = await _client
        .from('chat_threads')
        .select(_chatThreadSelect)
        .eq('shop_id', shopId)
        .eq('buyer_id', buyerId)
        .maybeSingle();

    if (existing != null) {
      return _hydrateChatThread(Map<String, dynamic>.from(existing), buyerId);
    }

    try {
      final inserted = await _client
          .from('chat_threads')
          .insert({'shop_id': shopId, 'buyer_id': buyerId})
          .select(_chatThreadSelect)
          .single();

      return _hydrateChatThread(Map<String, dynamic>.from(inserted), buyerId);
    } on PostgrestException catch (_) {
      final row = await _client
          .from('chat_threads')
          .select(_chatThreadSelect)
          .eq('shop_id', shopId)
          .eq('buyer_id', buyerId)
          .single();
      return _hydrateChatThread(Map<String, dynamic>.from(row), buyerId);
    }
  }

  Future<List<ChatMessage>> getThreadMessages(String threadId) async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);

    return Future.wait(
      (rows as List)
          .map((row) => ChatMessage.fromJson(Map<String, dynamic>.from(row)))
          .map(_hydrateChatMessage),
    );
  }

  Stream<List<ChatMessage>> watchThreadMessages(String threadId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at')
        .asyncMap((_) => getThreadMessages(threadId));
  }

  Future<DisputeCase?> getActiveDisputeForOrder(
    String orderId,
    String currentUserId,
  ) async {
    print(
      '[dispute-debug] getActiveDisputeForOrder start orderId=$orderId currentUserId=$currentUserId',
    );
    try {
      final dispute = await _client
          .from('disputes')
          .select(
            'id, order_id, raised_by, reason, status, resolution, dispute_conversations(id, buyer_id, seller_id)',
          )
          .eq('order_id', orderId)
          .inFilter('status', ['open', 'investigating', 'resolved'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (dispute == null) {
        print(
          '[dispute-debug] getActiveDisputeForOrder no dispute row orderId=$orderId',
        );
        return null;
      }

      print(
        '[dispute-debug] dispute row found id=${dispute['id']} status=${dispute['status']} conversationNodeType=${dispute['dispute_conversations']?.runtimeType}',
      );

      Map<String, dynamic>? conversationData;
      final conversationNode = dispute['dispute_conversations'];
      if (conversationNode is List && conversationNode.isNotEmpty) {
        conversationData = Map<String, dynamic>.from(
          conversationNode.first as Map,
        );
      } else if (conversationNode is Map) {
        conversationData = Map<String, dynamic>.from(conversationNode);
      }
      if (conversationData == null) {
        print(
          '[dispute-debug] dispute row missing conversation data disputeId=${dispute['id']}',
        );
        return null;
      }

      print(
        '[dispute-debug] conversation resolved conversationId=${conversationData['id']} buyerId=${conversationData['buyer_id']} sellerId=${conversationData['seller_id']}',
      );

      final participantRows = await _client
          .from('dispute_conversation_participants')
          .select(
            'participant_id, role_in_case, profiles(display_name, avatar_url)',
          )
          .eq('conversation_id', conversationData['id'] as String);

      print(
        '[dispute-debug] participant rows loaded conversationId=${conversationData['id']} count=${(participantRows as List).length}',
      );

      return DisputeCase(
        id: dispute['id'] as String,
        orderId: dispute['order_id'] as String,
        raisedBy: dispute['raised_by'] as String,
        reason: dispute['reason'] as String,
        status: dispute['status'] as String,
        resolution: dispute['resolution'] as String?,
        conversationId: conversationData['id'] as String,
        buyerId: conversationData['buyer_id'] as String,
        sellerId: conversationData['seller_id'] as String,
        participants: (participantRows)
            .map(
              (row) =>
                  DisputeParticipant.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (error) {
      print(
        '[dispute-debug] getActiveDisputeForOrder failed orderId=$orderId currentUserId=$currentUserId error=$error',
      );
      rethrow;
    }
  }

  Stream<DisputeCase?> watchActiveDisputeForOrder(
    String orderId,
    String currentUserId,
  ) async* {
    print(
      '[dispute-debug] watchActiveDisputeForOrder subscribe orderId=$orderId currentUserId=$currentUserId',
    );
    yield await getActiveDisputeForOrder(orderId, currentUserId);
    yield* _client
        .from('dispute_conversations')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .asyncMap((rows) async {
          print(
            '[dispute-debug] watchActiveDisputeForOrder realtime event orderId=$orderId rows=${rows.length}',
          );
          return getActiveDisputeForOrder(orderId, currentUserId);
        });
  }

  Future<List<ChatMessage>> getDisputeMessages(String conversationId) async {
    print(
      '[dispute-debug] getDisputeMessages start conversationId=$conversationId',
    );
    try {
      final rows = await _client
          .from('dispute_conversation_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      print(
        '[dispute-debug] getDisputeMessages rows loaded conversationId=$conversationId count=${(rows as List).length}',
      );

      return Future.wait(
        (rows)
            .map((row) => ChatMessage.fromJson(Map<String, dynamic>.from(row)))
            .map(_hydrateDisputeMessage),
      );
    } catch (error) {
      print(
        '[dispute-debug] getDisputeMessages failed conversationId=$conversationId error=$error',
      );
      rethrow;
    }
  }

  Stream<List<ChatMessage>> watchDisputeMessages(String conversationId) async* {
    print(
      '[dispute-debug] watchDisputeMessages subscribe conversationId=$conversationId',
    );
    yield await getDisputeMessages(conversationId);
    yield* _client
        .from('dispute_conversation_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .asyncMap((rows) async {
          print(
            '[dispute-debug] watchDisputeMessages realtime event conversationId=$conversationId rows=${rows.length}',
          );
          return getDisputeMessages(conversationId);
        });
  }

  Future<ChatAttachment> uploadDisputeAttachment(
    String conversationId,
    File file,
  ) async {
    final ext = file.path.split('.').last.toLowerCase();
    final originalName = _fileNameFromPath(file.path);
    final safeName = _sanitizeFileName(originalName);
    final storagePath =
        '$conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final sizeBytes = await file.length();

    await _client.storage
        .from(_disputeAttachmentBucket)
        .upload(
          storagePath,
          file,
          fileOptions: FileOptions(contentType: _mimeType(ext)),
        );

    final signedUrl = await _createSignedDisputeAttachmentUrl(storagePath);

    return ChatAttachment(
      url: signedUrl,
      path: storagePath,
      name: originalName,
      mimeType: _mimeType(ext),
      sizeBytes: sizeBytes,
    );
  }

  Future<ChatMessage> sendDisputeMessage({
    required String conversationId,
    required String senderId,
    String? body,
    ChatAttachment? attachment,
  }) async {
    final trimmedBody = body?.trim();
    final hasText = trimmedBody != null && trimmedBody.isNotEmpty;
    final hasAttachment = attachment != null;

    if (!hasText && !hasAttachment) {
      throw Exception('A message needs text or an attachment.');
    }

    final messageType = hasText && hasAttachment
        ? 'text_with_attachment'
        : hasAttachment
        ? 'attachment'
        : 'text';

    final row = await _client
        .from('dispute_conversation_messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'body': hasText ? trimmedBody : null,
          'message_type': messageType,
          'attachment_path': attachment?.path,
          'attachment_name': attachment?.name,
          'attachment_mime': attachment?.mimeType,
          'attachment_size_bytes': attachment?.sizeBytes,
        })
        .select()
        .single();

    return _hydrateDisputeMessage(
      ChatMessage.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  Future<void> markDisputeConversationRead(
    String conversationId,
    String participantId,
  ) async {
    final latestMessage = await _client
        .from('dispute_conversation_messages')
        .select('id, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    await _client
        .from('dispute_conversation_participants')
        .update({
          'last_read_message_id': latestMessage?['id'],
          'last_read_at':
              latestMessage?['created_at'] ??
              DateTime.now().toUtc().toIso8601String(),
        })
        .eq('conversation_id', conversationId)
        .eq('participant_id', participantId);
  }

  Future<ChatAttachment> uploadChatAttachment(
    String threadId,
    File file,
  ) async {
    final ext = file.path.split('.').last.toLowerCase();
    final originalName = _fileNameFromPath(file.path);
    final safeName = _sanitizeFileName(originalName);
    final storagePath =
        '$threadId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final sizeBytes = await file.length();

    await _client.storage
        .from(_chatAttachmentBucket)
        .upload(
          storagePath,
          file,
          fileOptions: FileOptions(contentType: _mimeType(ext)),
        );

    final signedUrl = await _createSignedChatAttachmentUrl(storagePath);

    return ChatAttachment(
      url: signedUrl,
      path: storagePath,
      name: originalName,
      mimeType: _mimeType(ext),
      sizeBytes: sizeBytes,
    );
  }

  Future<ChatMessage> sendChatMessage({
    required String threadId,
    required String senderId,
    String? body,
    ChatAttachment? attachment,
  }) async {
    final trimmedBody = body?.trim();
    final hasText = trimmedBody != null && trimmedBody.isNotEmpty;
    final hasAttachment = attachment != null;

    if (!hasText && !hasAttachment) {
      throw Exception('A message needs text or an attachment.');
    }

    final messageType = hasText && hasAttachment
        ? 'text_with_attachment'
        : hasAttachment
        ? 'attachment'
        : 'text';

    final row = await _client
        .from('chat_messages')
        .insert({
          'thread_id': threadId,
          'sender_id': senderId,
          'body': hasText ? trimmedBody : null,
          'message_type': messageType,
          'attachment_path': attachment?.path,
          'attachment_name': attachment?.name,
          'attachment_mime': attachment?.mimeType,
          'attachment_size_bytes': attachment?.sizeBytes,
        })
        .select()
        .single();

    return _hydrateChatMessage(
      ChatMessage.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  Future<void> markThreadRead(String threadId, String participantId) async {
    final latestMessage = await _client
        .from('chat_messages')
        .select('id, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    await _client.from('chat_thread_reads').upsert({
      'thread_id': threadId,
      'participant_id': participantId,
      'last_read_message_id': latestMessage?['id'],
      'last_read_at':
          latestMessage?['created_at'] ??
          DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'thread_id,participant_id');
  }

  Future<int> getUnreadThreadCountForBuyer(String userId) async {
    final threads = await getBuyerThreads(userId);
    return threads.where((thread) => thread.unreadCount > 0).length;
  }

  Future<int> getUnreadThreadCountForVendor(String vendorId) async {
    final threads = await getVendorThreads(vendorId);
    return threads.where((thread) => thread.unreadCount > 0).length;
  }

  // ── Reviews ────────────────────────────────────────────────────
  Future<List<ShopReview>> getShopReviews(String shopId) async {
    final rows = await _client
        .from('shop_reviews')
        .select(_shopReviewSelect)
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => ShopReview.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<ProductReview>> getProductReviews(String productId) async {
    final rows = await _client
        .from('product_reviews')
        .select(_productReviewSelect)
        .eq('product_id', productId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => ProductReview.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<ReviewSummary> getShopReviewSummary(String shopId) {
    return _getReviewSummary(
      table: 'shop_reviews',
      column: 'shop_id',
      value: shopId,
    );
  }

  Future<ReviewSummary> getProductReviewSummary(String productId) {
    return _getReviewSummary(
      table: 'product_reviews',
      column: 'product_id',
      value: productId,
    );
  }

  Future<bool> canReviewShop(String shopId, String buyerId) async {
    final orderId = await _getLatestEligibleShopOrderId(buyerId, shopId);
    return orderId != null;
  }

  Future<bool> canReviewProduct(String productId, String buyerId) async {
    final reviewContext = await _getLatestEligibleProductReviewContext(
      buyerId,
      productId,
    );
    return reviewContext != null;
  }

  Future<ShopReview> submitShopReview({
    required String shopId,
    required String buyerId,
    required int rating,
    String? reviewText,
  }) async {
    final orderId = await _getLatestEligibleShopOrderId(buyerId, shopId);
    if (orderId == null) {
      throw Exception('You can only review shops after a delivered order.');
    }

    final trimmedText = reviewText?.trim();
    final payload = {
      'shop_id': shopId,
      'buyer_id': buyerId,
      'order_id': orderId,
      'rating': rating,
      'review_text': trimmedText?.isEmpty == true ? null : trimmedText,
    };

    final existing = await _client
        .from('shop_reviews')
        .select('id')
        .eq('shop_id', shopId)
        .eq('buyer_id', buyerId)
        .maybeSingle();

    final row = existing == null
        ? await _client
              .from('shop_reviews')
              .insert(payload)
              .select(_shopReviewSelect)
              .single()
        : await _client
              .from('shop_reviews')
              .update(payload)
              .eq('id', existing['id'] as String)
              .select(_shopReviewSelect)
              .single();

    return ShopReview.fromJson(Map<String, dynamic>.from(row));
  }

  Future<ProductReview> submitProductReview({
    required String productId,
    required String buyerId,
    required int rating,
    String? reviewText,
  }) async {
    final reviewContext = await _getLatestEligibleProductReviewContext(
      buyerId,
      productId,
    );
    if (reviewContext == null) {
      throw Exception('You can only review products after delivery.');
    }

    final productRow = await _client
        .from('products')
        .select('shop_id')
        .eq('id', productId)
        .single();

    final trimmedText = reviewText?.trim();
    final payload = {
      'product_id': productId,
      'shop_id': productRow['shop_id'] as String,
      'buyer_id': buyerId,
      'order_id': reviewContext['order_id'],
      'order_item_id': reviewContext['order_item_id'],
      'rating': rating,
      'review_text': trimmedText?.isEmpty == true ? null : trimmedText,
    };

    final existing = await _client
        .from('product_reviews')
        .select('id')
        .eq('product_id', productId)
        .eq('buyer_id', buyerId)
        .maybeSingle();

    final row = existing == null
        ? await _client
              .from('product_reviews')
              .insert(payload)
              .select(_productReviewSelect)
              .single()
        : await _client
              .from('product_reviews')
              .update(payload)
              .eq('id', existing['id'] as String)
              .select(_productReviewSelect)
              .single();

    return ProductReview.fromJson(Map<String, dynamic>.from(row));
  }

  // ── Categories ────────────────────────────────────────────────
  Future<List<Category>> getCategories() async {
    final data = await _client
        .from('categories')
        .select()
        .order('sort_order', ascending: true);
    return (data as List).map((e) => Category.fromJson(e)).toList();
  }

  Future<List<String>> getTrendingSearches() async {
    final data = await _client
        .from('trending_searches')
        .select('term')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (data as List).map((e) => e['term'] as String).toList();
  }

  Stream<List<String>> watchTrendingSearches() {
    return _client
        .from('trending_searches')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .map(
          (rows) => rows
              .map((row) => row['term'] as String)
              .where((term) => term.trim().isNotEmpty)
              .toList(),
        );
  }

  // ── Subcategories ─────────────────────────────────────────────
  Future<List<Subcategory>> getSubcategories(String categoryId) async {
    final data = await _client
        .from('subcategories')
        .select()
        .eq('category_id', categoryId)
        .order('sort_order', ascending: true);
    return (data as List).map((e) => Subcategory.fromJson(e)).toList();
  }

  // ── Products ──────────────────────────────────────────────────
  static const _productSelect =
      '*, shops(name, logo_url), categories(name), subcategories(name), product_variants(*)';
  static const _orderSelect =
      '*, shops(name), order_items(*, products(title, images))';

  Map<String, dynamic> _productSummaryFromVariants(
    List<Map<String, dynamic>> variants,
    Map<String, dynamic> fallback,
  ) {
    if (variants.isEmpty) {
      return fallback;
    }

    final firstVariant = variants.first;
    final images =
        (firstVariant['images'] as List?)?.cast<String>() ?? const [];
    final totalStock = variants.fold<int>(
      0,
      (sum, variant) => sum + ((variant['stock_qty'] as num?)?.toInt() ?? 0),
    );

    return {
      ...fallback,
      'price': (firstVariant['price'] as num).toDouble(),
      'compare_at_price': (firstVariant['compare_at_price'] as num?)
          ?.toDouble(),
      'stock_qty': totalStock,
      'images': images,
    };
  }

  Future<void> _replaceProductVariants(
    String productId,
    List<Map<String, dynamic>> variants,
  ) async {
    final existingRows = await _client
        .from('product_variants')
        .select('id')
        .eq('product_id', productId);

    final existingIds = (existingRows as List)
        .map((row) => row['id'] as String)
        .toSet();
    final incomingIds = variants
        .map((variant) => variant['id'] as String?)
        .whereType<String>()
        .toSet();

    final idsToDelete = existingIds.difference(incomingIds);
    if (idsToDelete.isNotEmpty) {
      await _client
          .from('product_variants')
          .delete()
          .inFilter('id', idsToDelete.toList());
    }

    if (variants.isEmpty) {
      return;
    }

    await _client
        .from('product_variants')
        .upsert(
          variants
              .asMap()
              .entries
              .map(
                (entry) => {
                  ...entry.value,
                  'product_id': productId,
                  'sort_order': entry.key,
                },
              )
              .toList(),
        );
  }

  Future<List<Product>> getProducts({
    String? categoryId,
    String? subcategoryId,
    String? shopId,
    String? search,
    List<String>? tags,
    bool? onSale,
    bool? featured,
    String sortBy = 'created_at',
    bool ascending = false,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('products')
        .select(_productSelect)
        .eq('is_published', true);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (subcategoryId != null) {
      query = query.eq('subcategory_id', subcategoryId);
    }
    if (shopId != null) {
      query = query.eq('shop_id', shopId);
    }
    if (search != null && search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }
    if (tags != null && tags.isNotEmpty) {
      query = query.overlaps('tags', tags);
    }
    if (onSale == true) {
      query = query.not('compare_at_price', 'is', null);
    }
    if (featured == true) {
      query = query.eq('is_featured', true);
    }

    final data = await query
        .order(sortBy, ascending: ascending)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<Product>> getFeaturedProducts({int limit = 10}) async {
    final data = await _client
        .from('products')
        .select(_productSelect)
        .eq('is_published', true)
        .eq('is_featured', true)
        .order('featured_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<Product>> getOnSaleProducts({int limit = 10}) async {
    final data = await _client
        .from('products')
        .select(_productSelect)
        .eq('is_published', true)
        .not('compare_at_price', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> getProduct(String id) async {
    final data = await _client
        .from('products')
        .select(
          '*, shops(name, logo_url, slug, bio, location), categories(name), subcategories(name), product_variants(*)',
        )
        .eq('id', id)
        .single();
    return Product.fromJson(data);
  }

  // ── Shops ─────────────────────────────────────────────────────
  Future<List<Shop>> getShops() async {
    final data = await _client
        .from('shops')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);
    return (data as List).map((e) => Shop.fromJson(e)).toList();
  }

  Future<Shop?> getSpotlightShop() async {
    final data = await _client
        .from('shops')
        .select()
        .eq('is_active', true)
        .eq('is_spotlight', true)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Shop.fromJson(data);
  }

  Future<Shop> getShop(String id) async {
    final data = await _client.from('shops').select().eq('id', id).single();
    return Shop.fromJson(data);
  }

  Future<List<ShopMarketEvent>> getShopMarketEvents(
    String shopId, {
    bool upcomingOnly = true,
    bool includeInactive = false,
  }) async {
    var query = _client
        .from('shop_market_events')
        .select()
        .eq('shop_id', shopId);

    if (!includeInactive) {
      query = query.eq('is_active', true);
    }

    if (upcomingOnly) {
      final today = DateTime.now().toIso8601String().split('T').first;
      query = query.gte('event_date', today);
    }

    final data = await query
        .order('event_date', ascending: true)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => ShopMarketEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> replaceShopMarketEvents(
    String shopId,
    List<ShopMarketEvent> events,
  ) async {
    await _client.from('shop_market_events').delete().eq('shop_id', shopId);

    if (events.isEmpty) {
      return;
    }

    await _client
        .from('shop_market_events')
        .insert(events.map((event) => event.toInsertJson(shopId)).toList());
  }

  Future<List<ShippingOption>> getShopShippingOptions(String shopId) async {
    final data = await _client
        .from('shops')
        .select('shipping_options')
        .eq('id', shopId)
        .single();
    return ShippingOption.listFromJson(data['shipping_options']);
  }

  Future<void> updateShopShippingOptions(
    String shopId,
    List<ShippingOption> options,
  ) async {
    await _client
        .from('shops')
        .update({'shipping_options': options.map((o) => o.toJson()).toList()})
        .eq('id', shopId);
  }

  Future<void> setShopOfflineMode(
    String shopId, {
    required bool isOffline,
    DateTime? backToWorkDate,
  }) async {
    await _client
        .from('shops')
        .update({
          'is_offline': isOffline,
          'back_to_work_date': isOffline && backToWorkDate != null
              ? backToWorkDate.toIso8601String().split('T').first
              : null,
        })
        .eq('id', shopId);
  }

  // ── Stationery Requests ───────────────────────────────────────
  Future<StationeryCheckoutSession> createStationeryCheckout({
    required String shopId,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? deliveryAddress,
  }) async {
    final headers = await _authorizedFunctionHeaders();
    final response = await _client.functions.invoke(
      'create-payfast-stationery-checkout',
      headers: headers,
      body: {
        'shopId': shopId,
        'items': items,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (deliveryAddress != null && deliveryAddress.trim().isNotEmpty)
          'deliveryAddress': deliveryAddress.trim(),
      },
    );

    return StationeryCheckoutSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<StationeryCheckoutSession> createStationeryPaymentCheckout(
    String requestId,
  ) async {
    final headers = await _authorizedFunctionHeaders();
    final response = await _client.functions.invoke(
      'create-payfast-stationery-checkout',
      headers: headers,
      body: {'requestId': requestId},
    );

    return StationeryCheckoutSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> submitStationeryRequest({
    required String shopId,
    required String vendorId,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? deliveryAddress,
  }) async {
    await _client.from('stationery_requests').insert({
      'shop_id': shopId,
      'vendor_id': vendorId,
      'items': items,
      'notes': notes,
      'delivery_address': deliveryAddress,
    });
  }

  Future<List<StationeryRequest>> getVendorStationeryRequests(
    String vendorId,
  ) async {
    final data = await _client
        .from('stationery_requests')
        .select()
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => StationeryRequest.fromJson(e)).toList();
  }

  Stream<List<StationeryRequest>> watchVendorStationeryRequests(
    String vendorId,
  ) {
    return _client
        .from('stationery_requests')
        .stream(primaryKey: ['id'])
        .eq('vendor_id', vendorId)
        .order('created_at')
        .asyncMap((_) => getVendorStationeryRequests(vendorId));
  }

  Future<void> submitSupportTicket({
    required String userId,
    String? shopId,
    required String subject,
    required String message,
  }) async {
    await _client.from('support_tickets').insert({
      'user_id': userId,
      'shop_id': shopId,
      'subject': subject,
      'message': message,
    });
  }

  // ── Favourites ────────────────────────────────────────────────
  Future<List<Product>> getFavourites(String userId) async {
    final data = await _client
        .from('favourites')
        .select(
          'product_id, products(*, shops(name, logo_url), categories(name), subcategories(name))',
        )
        .eq('user_id', userId);
    return (data as List)
        .map((e) => Product.fromJson(e['products'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getFavouriteProductIds(String userId) async {
    final data = await _client
        .from('favourites')
        .select('product_id')
        .eq('user_id', userId);
    return (data as List).map((e) => e['product_id'] as String).toList();
  }

  Future<void> addFavourite(String userId, String productId) async {
    await _client.from('favourites').upsert({
      'user_id': userId,
      'product_id': productId,
    });
  }

  Future<void> removeFavourite(String userId, String productId) async {
    await _client
        .from('favourites')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }

  // ── Cart ──────────────────────────────────────────────────────
  Future<List<CartItem>> getCartItems(String userId) async {
    // Get or create cart
    var cartData = await _client
        .from('carts')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    cartData ??= await _client
        .from('carts')
        .insert({'user_id': userId})
        .select('id')
        .single();

    final cartId = cartData['id'] as String;

    // Remove items that are older than kCartExpiryHours
    final expiryCutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: kCartExpiryHours))
        .toIso8601String();
    await _client
        .from('cart_items')
        .delete()
        .eq('cart_id', cartId)
        .lt('created_at', expiryCutoff);

    final items = await _client
        .from('cart_items')
        .select('*, products($_productSelect), product_variants(*)')
        .eq('cart_id', cartId);

    return (items as List).map((e) => CartItem.fromJson(e)).toList();
  }

  Future<int> _getAvailableCartStock(
    String productId, {
    String? variantId,
  }) async {
    if (variantId != null) {
      final variant = await _client
          .from('product_variants')
          .select('stock_qty')
          .eq('id', variantId)
          .maybeSingle();
      return (variant?['stock_qty'] as num?)?.toInt() ?? 0;
    }

    final product = await _client
        .from('products')
        .select('stock_qty')
        .eq('id', productId)
        .single();
    return (product['stock_qty'] as num?)?.toInt() ?? 0;
  }

  Future<void> _ensureCartQuantityWithinStock({
    required String productId,
    String? variantId,
    required int desiredQuantity,
  }) async {
    final availableStock = await _getAvailableCartStock(
      productId,
      variantId: variantId,
    );
    if (desiredQuantity > availableStock) {
      throw StateError(stockLimitMessage(availableStock));
    }
  }

  Future<void> addToCart(
    String userId,
    String productId, {
    String? variantId,
    int quantity = 1,
  }) async {
    var cartData = await _client
        .from('carts')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    cartData ??= await _client
        .from('carts')
        .insert({'user_id': userId})
        .select('id')
        .single();

    final cartId = cartData['id'] as String;

    final existingRows = await _client
        .from('cart_items')
        .select('id, quantity, variant_id')
        .eq('cart_id', cartId)
        .eq('product_id', productId);

    Map<String, dynamic>? existing;
    for (final row in existingRows as List) {
      if (row['variant_id'] == variantId) {
        existing = Map<String, dynamic>.from(row);
        break;
      }
    }

    if (existing != null) {
      final newQty = (existing['quantity'] as int) + quantity;
      await _ensureCartQuantityWithinStock(
        productId: productId,
        variantId: variantId,
        desiredQuantity: newQty,
      );
      await _client
          .from('cart_items')
          .update({'quantity': newQty})
          .eq('id', existing['id'] as String);
    } else {
      await _ensureCartQuantityWithinStock(
        productId: productId,
        variantId: variantId,
        desiredQuantity: quantity,
      );
      await _client.from('cart_items').insert({
        'cart_id': cartId,
        'product_id': productId,
        'variant_id': variantId,
        'quantity': quantity,
      });
    }
  }

  Future<void> updateCartItemQuantity(String cartItemId, int quantity) async {
    final cartItem = await _client
        .from('cart_items')
        .select('product_id, variant_id')
        .eq('id', cartItemId)
        .single();

    await _ensureCartQuantityWithinStock(
      productId: cartItem['product_id'] as String,
      variantId: cartItem['variant_id'] as String?,
      desiredQuantity: quantity,
    );

    await _client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', cartItemId);
  }

  Future<void> removeCartItem(String cartItemId) async {
    await _client.from('cart_items').delete().eq('id', cartItemId);
  }

  // ── Orders ────────────────────────────────────────────────────
  Future<List<Order>> getOrders(String userId) async {
    final data = await _client
        .from('orders')
        .select(_orderSelect)
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<Order> getOrder(String id) async {
    final data = await _client
        .from('orders')
        .select(_orderSelect)
        .eq('id', id)
        .single();
    return Order.fromJson(data);
  }

  Stream<List<Order>> watchOrders(String userId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((_) => getOrders(userId));
  }

  Stream<Order> watchOrder(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .limit(1)
        .asyncMap((_) => getOrder(orderId));
  }

  // ── Shop Follows ─────────────────────────────────────────────
  Future<void> followShop(String userId, String shopId) async {
    await _client.from('shop_follows').upsert({
      'user_id': userId,
      'shop_id': shopId,
    });
  }

  Future<void> unfollowShop(String userId, String shopId) async {
    await _client
        .from('shop_follows')
        .delete()
        .eq('user_id', userId)
        .eq('shop_id', shopId);
  }

  Future<List<String>> getFollowedShopIds(String userId) async {
    final data = await _client
        .from('shop_follows')
        .select('shop_id')
        .eq('user_id', userId);
    return (data as List).map((e) => e['shop_id'] as String).toList();
  }

  Future<bool> isFollowing(String userId, String shopId) async {
    final data = await _client
        .from('shop_follows')
        .select('id')
        .eq('user_id', userId)
        .eq('shop_id', shopId)
        .maybeSingle();
    return data != null;
  }

  Future<int> getFollowerCount(String shopId) async {
    final data = await _client
        .from('shop_follows')
        .select('id')
        .eq('shop_id', shopId);
    return (data as List).length;
  }

  // ── Shop Posts ──────────────────────────────────────────────
  Future<List<ShopPost>> getShopPosts(
    String shopId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _client
        .from('shop_posts')
        .select('*, shops(name, logo_url)')
        .eq('shop_id', shopId)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => ShopPost.fromJson(e)).toList();
  }

  Future<List<ShopPost>> getFollowingFeed(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    // First get followed shop IDs
    final followedIds = await getFollowedShopIds(userId);
    if (followedIds.isEmpty) return [];

    final data = await _client
        .from('shop_posts')
        .select('*, shops(name, logo_url)')
        .inFilter('shop_id', followedIds)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => ShopPost.fromJson(e)).toList();
  }

  // ── Profile ───────────────────────────────────────────────────
  Future<Profile> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }

  Future<void> markVendorApprovalSeen(String userId) async {
    await _client
        .from('profiles')
        .update({
          'vendor_approved_seen_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<VendorPayoutProfile?> getVendorPayoutProfile(String vendorId) async {
    final data = await _client
        .from('vendor_payout_profiles')
        .select()
        .eq('vendor_id', vendorId)
        .maybeSingle();
    if (data == null) return null;
    return VendorPayoutProfile.fromJson(data);
  }

  Stream<VendorPayoutProfile?> watchVendorPayoutProfile(String vendorId) {
    return _client
        .from('vendor_payout_profiles')
        .stream(primaryKey: ['vendor_id'])
        .eq('vendor_id', vendorId)
        .limit(1)
        .asyncMap((_) => getVendorPayoutProfile(vendorId));
  }

  Future<VendorPayoutProfile> saveVendorPayoutProfile({
    required String vendorId,
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String branchCode,
    required String accountType,
    required String registeredPhone,
    required String registeredEmail,
  }) async {
    final payload = {
      'vendor_id': vendorId,
      'account_holder_name': accountHolderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'branch_code': branchCode,
      'account_type': accountType,
      'registered_phone': registeredPhone,
      'registered_email': registeredEmail,
      'identity_number': null,
      'business_registration_number': null,
      'verification_status': 'verified',
      'status_notes': null,
    };

    final data = await _client
        .from('vendor_payout_profiles')
        .upsert(payload)
        .select()
        .single();

    return VendorPayoutProfile.fromJson(data);
  }

  Future<VendorSubscription?> getVendorSubscription(String vendorId) async {
    final data = await _client
        .from('vendor_subscriptions')
        .select()
        .eq('vendor_id', vendorId)
        .maybeSingle();
    if (data == null) return null;
    return VendorSubscription.fromJson(data);
  }

  Stream<VendorSubscription?> watchVendorSubscription(String vendorId) {
    return _client
        .from('vendor_subscriptions')
        .stream(primaryKey: ['vendor_id'])
        .eq('vendor_id', vendorId)
        .limit(1)
        .asyncMap((_) => getVendorSubscription(vendorId));
  }

  Future<VendorSubscriptionCheckoutSession> createVendorSubscriptionCheckout() async {
    final headers = await _authorizedFunctionHeaders();
    final response = await _client.functions.invoke(
      'create-payfast-subscription',
      headers: headers,
    );

    return VendorSubscriptionCheckoutSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> cancelVendorSubscription() async {
    final headers = await _authorizedFunctionHeaders();
    final response = await _client.functions.invoke(
      'cancel-payfast-subscription',
      headers: headers,
    );

    final data = response.data;
    if (data is Map) {
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        throw Exception(error);
      }
    }
  }

  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  Future<Profile?> syncCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final pendingIntent = await _consumePendingAuthIntent();

    final existingProfile = await _client
        .from('profiles')
        .select('role, phone, avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    final currentMetadata = Map<String, dynamic>.from(user.userMetadata ?? {});
    final requestedRole =
        pendingIntent?['requested_role'] ??
        currentMetadata['requested_role'] as String? ??
        'buyer';
    final pendingDisplayName = pendingIntent?['display_name']?.trim();
    final metadataDisplayName =
        currentMetadata['display_name'] ??
        currentMetadata['full_name'] ??
        currentMetadata['name'];

    final updatedMetadata = <String, dynamic>{...currentMetadata};
    var shouldUpdateMetadata = false;

    if (updatedMetadata['requested_role'] != requestedRole) {
      updatedMetadata['requested_role'] = requestedRole;
      shouldUpdateMetadata = true;
    }

    if (pendingDisplayName != null &&
        pendingDisplayName.isNotEmpty &&
        (updatedMetadata['display_name'] as String?)?.trim().isEmpty != false) {
      updatedMetadata['display_name'] = pendingDisplayName;
      shouldUpdateMetadata = true;
    }

    if (shouldUpdateMetadata) {
      await _client.auth.updateUser(UserAttributes(data: updatedMetadata));
    }

    final effectiveUser = _client.auth.currentUser ?? user;

    final profileData = {
      'id': effectiveUser.id,
      'role': existingProfile?['role'] as String? ?? 'buyer',
      'display_name':
          (pendingDisplayName ??
                  metadataDisplayName ??
                  effectiveUser.email?.split('@').first)
              as String?,
      'email': effectiveUser.email,
      'phone': existingProfile?['phone'] as String?,
      'avatar_url':
          (existingProfile?['avatar_url'] ??
                  effectiveUser.userMetadata?['avatar_url'] ??
                  effectiveUser.userMetadata?['picture'])
              as String?,
    };

    await _client.from('profiles').upsert(profileData);
    return getProfile(effectiveUser.id);
  }

  Future<String> getPostAuthRoute({Profile? profile}) async {
    final currentUser = _client.auth.currentUser;
    final currentProfile =
        profile ??
        (currentUser == null ? null : await getProfile(currentUser.id));

    if (currentProfile?.isVendor == true) {
      return '/vendor';
    }

    final requestedRole =
        currentUser?.userMetadata?['requested_role'] as String? ?? 'buyer';

    if (requestedRole == 'vendor') {
      return '/vendor/onboarding';
    }

    return '/home';
  }

  // ── Order Creation ─────────────────────────────────────────────
  Future<CheckoutSession> createCheckout({
    required Map<String, dynamic> shippingAddress,
    required String shippingMethod,
    required double shippingCost,
    bool isGift = false,
    String? giftRecipient,
    String? giftMessage,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final session = _client.auth.currentSession;
    print(
      '[checkout-debug] createCheckout start userId=$userId sessionUser=${session?.user.id} accessTokenPresent=${(session?.accessToken.isNotEmpty ?? false)} refreshTokenPresent=${(session?.refreshToken?.isNotEmpty ?? false)}',
    );
    if (userId == null || userId.isEmpty) {
      throw const AuthException(
        'Please sign in again before starting checkout.',
      );
    }

    final headers = await _authorizedFunctionHeaders();
    print(
      '[checkout-debug] invoking create-checkout userId=$userId authHeaderPresent=${headers['Authorization']?.isNotEmpty ?? false} shippingMethod=$shippingMethod shippingCost=$shippingCost isGift=$isGift',
    );
    print(
      '[checkout-debug] shippingAddress keys=${shippingAddress.keys.toList()}',
    );

    final response = await _client.functions.invoke(
      'create-checkout',
      headers: headers,
      body: {
        'userId': userId,
        'shippingAddress': shippingAddress,
        'shippingMethod': shippingMethod,
        'shippingCost': shippingCost,
        'isGift': isGift,
        'giftRecipient': giftRecipient,
        'giftMessage': giftMessage,
      },
    );

    print(
      '[checkout-debug] create-checkout response status=${response.status} dataType=${response.data.runtimeType} data=${response.data}',
    );

    return CheckoutSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<CourierGuyLocker>> searchCourierGuyLockers({
    String? query,
    String? province,
    int? limit,
  }) async {
    final trimmedQuery = query?.trim();
    final trimmedProvince = province?.trim();
    final session = _client.auth.currentSession;
    print(
      '[locker-debug] search start sessionUser=${session?.user.id} accessTokenPresent=${(session?.accessToken.isNotEmpty ?? false)} refreshTokenPresent=${(session?.refreshToken?.isNotEmpty ?? false)} query="$trimmedQuery" province="$trimmedProvince" limit=$limit',
    );

    try {
      final headers = await _authorizedFunctionHeaders();
      print(
        '[locker-debug] invoking get-courier-guy-lockers authHeaderPresent=${headers['Authorization']?.isNotEmpty ?? false}',
      );

      final response = await _client.functions.invoke(
        'get-courier-guy-lockers',
        headers: headers,
        body: {
          if (trimmedQuery != null && trimmedQuery.isNotEmpty) 'query': trimmedQuery,
          if (trimmedProvince != null && trimmedProvince.isNotEmpty)
            'province': trimmedProvince,
          if (limit != null) 'limit': limit,
        },
      );

      print(
        '[locker-debug] response status=${response.status} dataType=${response.data.runtimeType} data=${response.data}',
      );

      final payload = Map<String, dynamic>.from(response.data as Map);
      final data = (payload['lockers'] as List? ?? const [])
          .map((entry) => CourierGuyLocker.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList(growable: false);
      print('[locker-debug] parsed lockers count=${data.length}');
      return data;
    } catch (error, stackTrace) {
      print(
        '[locker-debug] search failed error=$error stackTrace=$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> clearCart(String userId) async {
    final cartData = await _client
        .from('carts')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (cartData != null) {
      await _client
          .from('cart_items')
          .delete()
          .eq('cart_id', cartData['id'] as String);
    }
  }

  Future<void> confirmReceipt(String orderId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AuthException(
        'Please sign in again before confirming receipt.',
      );
    }
    await _client.functions.invoke(
      'release-escrow',
      headers: await _authorizedFunctionHeaders(),
      body: {'orderId': orderId, 'userId': userId},
    );
  }

  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke(
      'delete-account',
      headers: await _authorizedFunctionHeaders(),
    );

    if (response.status < 200 || response.status >= 300) {
      final payload = response.data;
      if (payload is Map && payload['error'] is String) {
        throw Exception(payload['error'] as String);
      }
      throw Exception('Could not delete your account right now.');
    }

    await _client.auth.signOut();
  }

  Future<DisputeOpenResult> createDispute(
    String orderId,
    String raisedBy,
    String reason,
  ) async {
    final response = await _client.functions.invoke(
      'open-dispute',
      headers: await _authorizedFunctionHeaders(),
      body: {'orderId': orderId, 'userId': raisedBy, 'reason': reason},
    );
    return DisputeOpenResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  // ── Addresses ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSavedAddresses(String userId) async {
    final data = await _client
        .from('profiles')
        .select('shipping_addresses')
        .eq('id', userId)
        .single();
    final addresses = data['shipping_addresses'];
    if (addresses == null) return [];
    return (addresses as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveAddresses(
    String userId,
    List<Map<String, dynamic>> addresses,
  ) async {
    await _client
        .from('profiles')
        .update({'shipping_addresses': addresses})
        .eq('id', userId);
  }

  // ══════════════════════════════════════════════════════════════
  //  VENDOR SERVICE METHODS
  // ══════════════════════════════════════════════════════════════

  // ── Vendor Shop ─────────────────────────────────────────────
  Future<Shop?> getVendorShop(String vendorId) async {
    final data = await _client
        .from('shops')
        .select()
        .eq('vendor_id', vendorId)
        .maybeSingle();
    if (data == null) return null;
    return Shop.fromJson(data);
  }

  Future<void> updateShop(String shopId, Map<String, dynamic> updates) async {
    await _client.from('shops').update(updates).eq('id', shopId);
  }

  // ── Vendor Products ─────────────────────────────────────────
  Future<List<Product>> getVendorProducts(String shopId) async {
    final data = await _client
        .from('products')
        .select('*, categories(name), subcategories(name), product_variants(*)')
        .eq('shop_id', shopId)
        .filter('archived_at', 'is', null)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> createProduct(
    String shopId,
    Map<String, dynamic> data,
  ) async {
    final variants = List<Map<String, dynamic>>.from(
      (data.remove('variants') as List?)?.map(
            (entry) => Map<String, dynamic>.from(entry as Map),
          ) ??
          const [],
    );
    final productPayload = _productSummaryFromVariants(
      variants,
      Map<String, dynamic>.from(data),
    );
    final row = await _client
        .from('products')
        .insert({'shop_id': shopId, ...productPayload})
        .select('*, categories(name), subcategories(name), product_variants(*)')
        .single();
    final product = Product.fromJson(row);
    if (variants.isNotEmpty) {
      await _replaceProductVariants(product.id, variants);
      return getProduct(product.id);
    }
    return product;
  }

  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    final mutableUpdates = Map<String, dynamic>.from(updates);
    final variants = List<Map<String, dynamic>>.from(
      (mutableUpdates.remove('variants') as List?)?.map(
            (entry) => Map<String, dynamic>.from(entry as Map),
          ) ??
          const [],
    );
    final productPayload = _productSummaryFromVariants(
      variants,
      mutableUpdates,
    );
    await _client.from('products').update(productPayload).eq('id', productId);
    await _replaceProductVariants(productId, variants);
  }

  Future<void> deleteProduct(String productId) async {
    // Soft delete: we can't hard-delete because order_items.product_id
    // still references this product for historical order records.
    // Archiving hides the product from buyers (via RLS) and from the
    // vendor's own list, while keeping order history intact.
    await _client
        .from('products')
        .update({
          'archived_at': DateTime.now().toUtc().toIso8601String(),
          'is_published': false,
        })
        .eq('id', productId);
  }

  // ── Vendor Orders ───────────────────────────────────────────
  Future<List<Order>> getShopOrders(String shopId) async {
    final data = await _client
        .from('orders')
        .select(_orderSelect)
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  Stream<List<Order>> watchShopOrders(String shopId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .asyncMap((_) => getShopOrders(shopId));
  }

  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? trackingNumber,
    String? trackingUrl,
  }) async {
    if (status == 'shipped') {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw const AuthException(
          'Please sign in again before updating the order.',
        );
      }
      await _client.functions.invoke(
        'mark-order-shipped',
        headers: await _authorizedFunctionHeaders(),
        body: {
          'orderId': orderId,
          'trackingNumber': trackingNumber,
          'trackingUrl': trackingUrl,
          'userId': userId,
        },
      );
      return;
    }

    final updates = <String, dynamic>{'status': status};
    if (trackingNumber != null) {
      updates['tracking_number'] = trackingNumber;
    }
    if (trackingUrl != null) {
      updates['tracking_url'] = trackingUrl;
    }
    await _client.from('orders').update(updates).eq('id', orderId);
  }

  // ── Vendor Earnings ─────────────────────────────────────────
  Future<Map<String, double>> getShopEarnings(String shopId) async {
    final orders = await _client
        .from('orders')
        .select('id, total, shipping_cost')
        .eq('shop_id', shopId);

    if ((orders as List).isEmpty) {
      return {'totalSales': 0, 'held': 0, 'released': 0, 'fees': 0};
    }

    final orderIds = (orders).map((o) => o['id'] as String).toList();

    final escrowData = await _client
        .from('escrow_transactions')
        .select()
        .inFilter('order_id', orderIds);

    double held = 0;
    double released = 0;
    double fees = 0;
    double totalSales = 0;

    for (final e in escrowData as List) {
      final amount = (e['amount'] as num).toDouble();
      final fee = (e['platform_fee'] as num?)?.toDouble() ?? 0;
      fees += fee;
      totalSales += amount;
      if (e['status'] == 'held') held += amount;
      if (e['status'] == 'released') released += (amount - fee);
    }

    return {
      'totalSales': totalSales,
      'held': held,
      'released': released,
      'fees': fees,
    };
  }

  // ── Vendor Application ──────────────────────────────────────
  Future<VendorApplication?> getVendorApplication(String userId) async {
    final data = await _client
        .from('vendor_applications')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return VendorApplication.fromJson(data);
  }

  Stream<VendorApplication?> watchVendorApplication(String userId) {
    return _client
        .from('vendor_applications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .limit(1)
        .asyncMap((_) => getVendorApplication(userId));
  }

  Future<VendorApplication> submitVendorApplication({
    required String userId,
    required String businessName,
    String? motivation,
    String? portfolioUrl,
    List<String>? proofImageUrls,
    String? location,
    String? deliveryInfo,
    String? turnaroundTime,
  }) async {
    final appData = await _client
        .from('vendor_applications')
        .insert({
          'user_id': userId,
          'business_name': businessName,
          'motivation': motivation,
          'portfolio_url': portfolioUrl,
          'proof_image_urls': proofImageUrls ?? const [],
          'location': location,
          'delivery_info': deliveryInfo,
          'turnaround_time': turnaroundTime,
          'status': 'pending',
        })
        .select()
        .single();

    return VendorApplication.fromJson(appData);
  }

  Future<VendorApplication> submitVendorOnboarding({
    required String userId,
    required String businessName,
    String? motivation,
    String? portfolioUrl,
    List<String>? proofImageUrls,
    String? location,
    String? deliveryInfo,
    String? turnaroundTime,
  }) async {
    final appData = await _client
        .from('vendor_applications')
        .insert({
          'user_id': userId,
          'business_name': businessName,
          'motivation': motivation,
          'portfolio_url': portfolioUrl,
          'proof_image_urls': proofImageUrls ?? const [],
          'location': location,
          'delivery_info': deliveryInfo,
          'turnaround_time': turnaroundTime,
          'status': 'pending',
        })
        .select()
        .single();

    return VendorApplication.fromJson(appData);
  }

  Future<void> activateVendorAccount({
    required String userId,
    required String businessName,
    String? location,
  }) async {
    throw Exception(
      'Vendor accounts are provisioned by an admin after approval.',
    );
  }

  // ── Shop Posts (Vendor) ─────────────────────────────────────
  Future<ShopPost> createShopPost(
    String shopId, {
    required String caption,
    List<String> mediaUrls = const [],
  }) async {
    final data = await _client
        .from('shop_posts')
        .insert({
          'shop_id': shopId,
          'caption': caption,
          'media_urls': mediaUrls,
          'is_published': true,
        })
        .select('*, shops(name, logo_url)')
        .single();
    return ShopPost.fromJson(data);
  }

  Future<void> updateShopPost(
    String postId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('shop_posts').update(updates).eq('id', postId);
  }

  Future<void> deleteShopPost(String postId) async {
    await _client.from('shop_posts').delete().eq('id', postId);
  }
}
