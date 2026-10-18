import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';

/// The earliest and latest a post may be scheduled for, relative to now.
const composerScheduleMinLead = Duration(minutes: 10);
const composerScheduleMaxLead = Duration(days: 60);

/// Validates a candidate schedule time; returns an error message or null.
String? composerScheduleError(DateTime? scheduledFor, {DateTime? now}) {
  if (scheduledFor == null) return null;
  final reference = now ?? DateTime.now();
  if (scheduledFor.isBefore(reference.add(composerScheduleMinLead))) {
    return 'Schedule at least 10 minutes from now.';
  }
  if (scheduledFor.isAfter(reference.add(composerScheduleMaxLead))) {
    return 'Schedule within the next 60 days.';
  }
  return null;
}

/// What an edit should write to `scheduled_for`.
///
/// * A post that is already live keeps its go-live time (it can't be
///   un-published by scheduling it again).
/// * A still-scheduled post can be moved to another time, or switched to
///   "post now", which goes live at [now] so it lands at the top of feeds
///   instead of at its original creation time.
({bool change, DateTime? value}) composerEditedSchedule({
  required DateTime? original,
  required DateTime? edited,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  if (original == null || !original.isAfter(reference)) {
    return (change: false, value: original);
  }
  if (edited == original) return (change: false, value: original);
  return (change: true, value: edited ?? reference);
}

String composerFormatScheduleLabel(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour24 = dateTime.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} · $hour12:$minute $period';
}

/// "Post now" vs "Schedule" toggle with a date + time picker for the
/// scheduled option. Reports the chosen [DateTime] (or null for "now") via
/// [onChanged], and any validation error via [errorText] (computed by the
/// caller with [composerScheduleError] so it can be shown inline).
class ComposerScheduleSection extends StatelessWidget {
  const ComposerScheduleSection({
    super.key,
    required this.scheduledFor,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final DateTime? scheduledFor;
  final ValueChanged<DateTime?> onChanged;
  final String? errorText;
  final bool enabled;

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final initial = scheduledFor ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(composerScheduleMaxLead),
      helpText: 'SELECT DATE',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'SELECT TIME',
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isScheduled = scheduledFor != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When to post',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ScheduleChoice(
                key: const Key('composer-post-now'),
                label: 'Post now',
                icon: Icons.bolt_rounded,
                selected: !isScheduled,
                onTap: enabled ? () => onChanged(null) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScheduleChoice(
                key: const Key('composer-schedule'),
                label: 'Schedule',
                icon: Icons.schedule_rounded,
                selected: isScheduled,
                onTap: enabled
                    ? () => onChanged(
                        scheduledFor ??
                            DateTime.now().add(const Duration(hours: 1)),
                      )
                    : null,
              ),
            ),
          ],
        ),
        if (isScheduled) ...[
          const SizedBox(height: 10),
          InkWell(
            key: const Key('composer-schedule-picker'),
            onTap: enabled ? () => _pickDateTime(context) : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: errorText != null ? AppTheme.error : AppTheme.sand,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: AppTheme.terracotta,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      composerFormatScheduleLabel(scheduledFor!),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Text(
              errorText!,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error),
            ),
          ],
        ],
      ],
    );
  }
}

class _ScheduleChoice extends StatelessWidget {
  const _ScheduleChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.terracotta.withValues(alpha: 0.12)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.terracotta : AppTheme.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? AppTheme.terracotta : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.terracotta : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
