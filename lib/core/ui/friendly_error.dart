import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../features/safety/content_filter.dart';

/// Plain-language message for an error. Never shows raw exception text.
String friendlyErrorMessage(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  // The server's community-guidelines language filter rejected the text.
  final ugcMessage = ugcErrorMessage(error);
  if (ugcMessage != null) return ugcMessage;
  if (error is SocketException || error is TimeoutException) {
    return "You're offline or the connection is slow. Check your connection and try again.";
  }
  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection closed') ||
      text.contains('network')) {
    return "You're offline or the connection is slow. Check your connection and try again.";
  }
  if (text.contains("shop isn't set up")) {
    return "Your shop isn't set up yet. Please contact Artisan Lane support.";
  }
  if (text.contains('jwt') || text.contains('not authenticated')) {
    return 'Your session has expired. Please sign in again.';
  }
  return fallback;
}

/// Friendly full-area error with a retry action, for screens that failed to load.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    this.error,
    this.title = "Couldn't load this",
    this.onRetry,
  });

  final Object? error;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              friendlyErrorMessage(error),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
