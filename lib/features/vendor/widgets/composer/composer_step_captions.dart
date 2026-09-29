import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';

/// One caption field per tutorial step, shown under its thumbnail.
/// [thumbnails] and [controllers] must be the same length and order as the
/// composer's media list.
class ComposerStepCaptions extends StatelessWidget {
  const ComposerStepCaptions({
    super.key,
    required this.thumbnails,
    required this.controllers,
    this.enabled = true,
  });

  final List<Widget> thumbnails;
  final List<TextEditingController> controllers;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (thumbnails.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step captions',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tell followers what happens at each step (up to 200 characters).',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < thumbnails.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(width: 52, height: 52, child: thumbnails[i]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: Key('composer-step-caption-$i'),
                    controller: controllers[i],
                    enabled: enabled,
                    maxLength: 200,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Step ${i + 1} caption',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
