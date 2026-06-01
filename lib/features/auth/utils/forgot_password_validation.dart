const forgotPasswordEmailNotFoundMessage =
    'No Artisan Lane account exists for this email address.';

String normalizeForgotPasswordEmail(String value) => value.trim().toLowerCase();

bool isRegisteredEmailLookupResult(Object? row) => row is Map && row['id'] is String;
