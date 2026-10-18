import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';

const composerPollMinOptions = 2;
const composerPollMaxOptions = 4;

/// Duration chips offered for closing a poll automatically.
enum ComposerPollDuration {
  oneDay('1 day', Duration(days: 1)),
  threeDays('3 days', Duration(days: 3)),
  oneWeek('1 week', Duration(days: 7)),
  noEnd('No end', null);

  const ComposerPollDuration(this.label, this.duration);
  final String label;
  final Duration? duration;
}

/// Validates a poll draft. Returns an error message, or null when valid.
/// [imageCount] enforces the "at least one image" rule the poll format
/// keeps from the existing photo-required rule.
String? composerPollError({
  required String question,
  required List<String> options,
  required int imageCount,
}) {
  if (question.trim().isEmpty) return 'Add a question for your poll.';
  if (question.trim().length > 200) {
    return 'Keep the question under 200 characters.';
  }
  final filled = options
      .map((o) => o.trim())
      .where((o) => o.isNotEmpty)
      .toList();
  if (filled.length < composerPollMinOptions) {
    return 'Add at least 2 options.';
  }
  if (filled.map((o) => o.toLowerCase()).toSet().length != filled.length) {
    return 'Each poll option needs to be different.';
  }
  if (imageCount < 1) return 'Add a photo to go with your poll.';
  return null;
}

/// When a new poll should close: [duration] after the post goes live (its
/// schedule, or [now] for an immediate post), or never when null.
DateTime? composerPollClosesAt({
  required Duration? duration,
  DateTime? scheduledFor,
  DateTime? now,
}) {
  if (duration == null) return null;
  return (scheduledFor ?? now ?? DateTime.now()).add(duration);
}

/// Editable question, 2–4 options and an optional auto-close duration.
class ComposerPollEditor extends StatelessWidget {
  const ComposerPollEditor({
    super.key,
    required this.questionController,
    required this.optionControllers,
    required this.selectedDuration,
    required this.onDurationChanged,
    required this.onAddOption,
    required this.onRemoveOption,
    this.enabled = true,
  });

  final TextEditingController questionController;
  final List<TextEditingController> optionControllers;
  final ComposerPollDuration selectedDuration;
  final ValueChanged<ComposerPollDuration> onDurationChanged;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poll',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('composer-poll-question'),
          controller: questionController,
          enabled: enabled,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ask your followers…'),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < optionControllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('composer-poll-option-$i'),
                    controller: optionControllers[i],
                    enabled: enabled,
                    maxLength: 60,
                    decoration: InputDecoration(
                      hintText: 'Option ${i + 1}',
                      counterText: '',
                    ),
                  ),
                ),
                if (optionControllers.length > composerPollMinOptions)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      key: Key('composer-poll-remove-option-$i'),
                      onPressed: enabled ? () => onRemoveOption(i) : null,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppTheme.error,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (optionControllers.length < composerPollMaxOptions)
          TextButton.icon(
            key: const Key('composer-poll-add-option'),
            onPressed: enabled ? onAddOption : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add option'),
          ),
        const SizedBox(height: 8),
        Text(
          'Closes after',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final duration in ComposerPollDuration.values)
              _DurationChip(
                key: Key('composer-poll-duration-${duration.name}'),
                duration: duration,
                selected: selectedDuration == duration,
                onTap: enabled ? () => onDurationChanged(duration) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    super.key,
    required this.duration,
    required this.selected,
    required this.onTap,
  });

  final ComposerPollDuration duration;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.terracotta.withValues(alpha: 0.12)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.terracotta : AppTheme.sand,
          ),
        ),
        child: Text(
          duration.label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.terracotta : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
