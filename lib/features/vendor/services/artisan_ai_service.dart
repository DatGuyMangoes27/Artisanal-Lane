import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_providers.dart';

final artisanAiServiceProvider = Provider<ArtisanAiService>(
  (ref) => ArtisanAiService(ref.read(supabaseClientProvider)),
);

/// What the artisan-ai edge function says this account can actually do.
/// Anything other than an explicit `true` counts as unavailable.
class ArtisanAiCapabilities {
  const ArtisanAiCapabilities({this.listing = false, this.image = false});

  /// Nothing enabled. Used while unknown, on any failure, and when signed out.
  static const none = ArtisanAiCapabilities();

  factory ArtisanAiCapabilities.fromJson(Map<String, dynamic> json) =>
      ArtisanAiCapabilities(
        listing: json['listing'] == true,
        image: json['image'] == true,
      );

  /// AI listing text (title & description) and AI caption polish.
  final bool listing;

  /// AI-styled product photos.
  final bool image;

  bool get any => listing || image;
}

/// Single source of truth for whether AI UI may be shown. Fails closed: an
/// error, a missing session or an unexpected response all mean "hide AI".
/// Callers must treat loading as disabled too, so AI UI never flashes.
final artisanAiCapabilitiesProvider =
    FutureProvider.autoDispose<ArtisanAiCapabilities>((ref) async {
      if (ref.watch(currentUserIdProvider) == null) {
        return ArtisanAiCapabilities.none;
      }
      try {
        final caps = await ref.read(artisanAiServiceProvider).capabilities();
        return ArtisanAiCapabilities.fromJson(caps);
      } catch (_) {
        return ArtisanAiCapabilities.none;
      }
    });

/// Synchronous view of [artisanAiCapabilitiesProvider]: [ArtisanAiCapabilities.none]
/// until the check has finished.
ArtisanAiCapabilities watchArtisanAiCapabilities(WidgetRef ref) =>
    ref.watch(artisanAiCapabilitiesProvider).value ??
    ArtisanAiCapabilities.none;

class ArtisanAiException implements Exception {
  final String code;
  const ArtisanAiException(this.code);
  String get message => switch (code) {
    'ai_not_enabled' || 'not_configured' =>
      'This tool isn''t available right now. Your listing is unchanged.',
    'daily_limit_reached' =>
      'You''ve reached today''s limit. Please try again tomorrow.',
    'sign_in_required' => 'Please sign in again and reopen Listing Studio.',
    'provide_product_facts' =>
      'Add a few confirmed details about your product first.',
    'image_too_large' ||
    'request_too_large' => 'Choose a photo smaller than 8 MB.',
    'invalid_image' ||
    'unsupported_image' => 'Choose a JPEG, PNG or WebP photo.',
    'generation_refused' =>
      'This request could not be generated. Your original is unchanged.',
    'generation_failed' ||
    'failed' ||
    'generation_incomplete' ||
    'invalid_generation' =>
      'Generation did not finish successfully. Your listing is unchanged.',
    'pending' =>
      'This request is still processing. Check its result before starting another.',
    'shop_not_owned' => 'This works only for your own shop.',
    _ =>
      'We could not confirm the result. Check again to avoid generating twice.',
  };
}

class ArtisanAiService {
  final SupabaseClient client;
  ArtisanAiService(this.client);
  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final user = client.auth.currentUser?.id;
    if (user == null) throw const ArtisanAiException('sign_in_required');
    try {
      final response = await client.functions.invoke('artisan-ai', body: body);
      if (user != client.auth.currentUser?.id) {
        throw const ArtisanAiException('sign_in_required');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['code'] != null) {
        throw ArtisanAiException(data['code'] as String);
      }
      return data;
    } on FunctionException catch (e) {
      final details = e.details;
      throw ArtisanAiException(
        details is Map
            ? details['code'] as String? ?? 'unavailable'
            : 'unavailable',
      );
    }
  }

  Future<Map<String, dynamic>> capabilities() =>
      _call({'operation': 'capabilities'});
  Future<Map<String, dynamic>> generate(Map<String, dynamic> request) async {
    final response = await _call(request);
    if (response['status'] != 'succeeded') {
      throw ArtisanAiException(response['status'] as String? ?? 'unavailable');
    }
    return Map<String, dynamic>.from(response['result'] as Map);
  }

  Future<Uint8List> download(String path) async {
    final user = client.auth.currentUser?.id;
    if (user == null || !path.startsWith('$user/')) {
      throw const ArtisanAiException('sign_in_required');
    }
    final bytes = await client.storage
        .from('artisan-ai-results')
        .download(path);
    if (user != client.auth.currentUser?.id) {
      throw const ArtisanAiException('sign_in_required');
    }
    return bytes;
  }
}

/// Cost-based gross margin estimate, not a market valuation or tax calculation.
double? suggestedListingPrice({
  required double materials,
  required double labour,
  required double overheads,
  required double margin,
}) {
  if ([materials, labour, overheads, margin].any((n) => !n.isFinite || n < 0) ||
      margin >= 100 ||
      materials + labour + overheads <= 0) {
    return null;
  }
  return (materials + labour + overheads) / (1 - margin / 100);
}
