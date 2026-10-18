/// Client-side mirror of the server's objectionable-language filter
/// (`public.contains_blocked_terms` in
/// supabase/migrations/20261018100000_ugc_safety.sql).
///
/// The server is authoritative: every user-visible text column is checked by a
/// trigger. This copy lets composers show a friendly inline error before
/// sending. Keep [blockedTermPatterns] identical to the SQL list.
///
/// Every pattern is matched as a whole word, case-insensitively, so innocent
/// words that merely contain a term (Scunthorpe, cocktail, assassin, Pakistan,
/// spice, therapist, retardant) are allowed. Mild words (damn, hell, crap,
/// bloody, shit) are deliberately not listed. See the migration for the list
/// of terms left out because of innocent craft-marketplace meanings.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// The message raised by the server trigger, word for word.
const blockedTermsServerMessage =
    "This text contains language that isn't allowed on Artisan Lane.";

/// Friendly copy shown in the app when text is rejected.
const blockedTermsFriendlyMessage =
    "This contains language that isn't allowed on Artisan Lane. "
    'Please edit it and try again.';

/// Regex fragments, identical to the SQL array in the migration.
const blockedTermPatterns = <String>[
  // Severe profanity
  r'f[u*@#]+c?k+(?:s|ed|er|ers|ing|in|face|faces|head|heads|wit|wits)?',
  r'fck(?:s|ed|er|ers|ing)?',
  r'motherf[u*@#]+c?k+(?:a|as|er|ers|ing|in)?',
  r'cunts?',
  r'twats?',
  r'cocksuck(?:er|ers|ing)?',
  r'dickheads?',
  r'a(?:ss|rse)holes?',
  // Explicit sexual terms
  r'porn(?:o|os|ography|ographic|hub)?',
  r'blowjobs?',
  r'handjobs?',
  r'cumshots?',
  r'creampies?',
  r'gangbang(?:s|ed|ing)?',
  r'deepthroat(?:s|ed|ing)?',
  r'dildos?',
  r'masturbat(?:e|es|ed|ing|ion)',
  r'jizz',
  r'clits?',
  r'hentai',
  r'orgy|orgies',
  r'whores?',
  r'sluts?|slutty',
  r'bestiality',
  r'pa?edophil(?:e|es|ia)',
  // Slurs
  r'n[i1]gg(?:a|as|ah|az|er|ers)',
  r'sandn[i1]gg(?:a|as|er|ers)',
  r'k[a@]ff[i1]rs?',
  r'kaffers?',
  r'hotnots?',
  r'coolies?',
  r'faggots?',
  r'retards?|retarded',
  r'spics?',
  r'kikes?',
  r'gooks?',
  r'pakis?',
  r'wetbacks?',
  r'trann(?:y|ies)',
  r'ragheads?',
  r'towelheads?',
  r'jungle ?bunn(?:y|ies)',
];

/// Postgres `\m`/`\M` word boundaries: a word character is a letter, digit or
/// underscore.
final RegExp _blockedTerms = RegExp(
  '(?<![A-Za-z0-9_])(?:${blockedTermPatterns.join('|')})(?![A-Za-z0-9_])',
  caseSensitive: false,
);

/// True when [text] contains a blocked term as a whole word.
bool containsBlockedTerms(String? text) {
  if (text == null || text.isEmpty) return false;
  return _blockedTerms.hasMatch(text);
}

/// Validator-style helper for composers: returns [blockedTermsFriendlyMessage]
/// when any of [texts] contains a blocked term, otherwise null.
///
/// ```dart
/// final error = validateUgcText([caption, ...stepCaptions]);
/// if (error != null) setState(() => _captionError = error);
/// ```
String? validateUgcText(Iterable<String?> texts) {
  for (final text in texts) {
    if (containsBlockedTerms(text)) return blockedTermsFriendlyMessage;
  }
  return null;
}

/// True when [error] is the server trigger's objectionable-language rejection.
bool isBlockedTermsError(Object? error) {
  if (error is PostgrestException) {
    return error.message.contains(blockedTermsServerMessage) ||
        error.hint == 'blocked_terms';
  }
  return error?.toString().contains(blockedTermsServerMessage) ?? false;
}

/// [blockedTermsFriendlyMessage] when [error] is the server's language-filter
/// rejection, otherwise null. Lets callers keep their existing error handling:
///
/// ```dart
/// final message = ugcErrorMessage(error) ?? friendlyErrorMessage(error);
/// ```
String? ugcErrorMessage(Object? error) =>
    isBlockedTermsError(error) ? blockedTermsFriendlyMessage : null;
