const googleSignInCouldNotContinueMessage =
    'Google sign-in could not continue. Please try again or create an account.';

const googleSignInStartFailedMessage =
    'Unable to start Google sign-in. Please check your connection and try again.';

String friendlySocialAuthError(Object error) {
  final message = error.toString();
  final normalized = message.toLowerCase();

  if (normalized.contains('googlesigninexception') ||
      normalized.contains('account reauth failed') ||
      normalized.contains('canceled')) {
    return googleSignInCouldNotContinueMessage;
  }

  return googleSignInStartFailedMessage;
}
