import 'package:flutter/material.dart';

import '../buyer/screens/legal_doc_screen.dart';

/// The full community guidelines, in the same style as Terms and Privacy.
/// Route: /community-guidelines (public, also reachable from Settings and
/// Help & Support).
class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocScreen(
    title: 'Community Guidelines',
    type: 'community-guidelines',
  );
}
