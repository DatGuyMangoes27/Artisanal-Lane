import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../widgets/gradient_button.dart';

/// Rounded card used for every Listing Studio section.
class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // A Material (not a coloured box) so list tiles and ink inside paint.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.sand.withValues(alpha: .45)),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Tool intro: Playfair heading and a one-line explanation.
class StudioIntro extends StatelessWidget {
  const StudioIntro({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small bold label for a group of controls inside a [StudioCard].
class StudioLabel extends StatelessWidget {
  const StudioLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
    ),
  );
}

/// Muted helper copy (≥12px per the design language).
class StudioNote extends StatelessWidget {
  const StudioNote(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 12,
      height: 1.45,
      color: color ?? AppTheme.textSecondary,
    ),
  );
}

/// Sticky bottom bar holding a tool's one primary action.
class StudioActionBar extends StatelessWidget {
  const StudioActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: GradientButton(
            label: label,
            icon: icon,
            onPressed: onPressed,
            isLoading: isLoading,
            verticalPadding: 14,
            borderRadius: 26,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// Scrollable tool body above its sticky [StudioActionBar].
class StudioToolLayout extends StatelessWidget {
  const StudioToolLayout({
    super.key,
    required this.children,
    required this.actionBar,
  });

  final List<Widget> children;
  final Widget actionBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        actionBar,
      ],
    );
  }
}

/// Inline, plain-language error line.
class StudioError extends StatelessWidget {
  const StudioError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(child: StudioNote(message, color: AppTheme.error)),
        ],
      ),
    );
  }
}

/// Input styling shared by the studio's text fields.
InputDecoration studioInputDecoration(
  String label, {
  String? helper,
  String? prefix,
  String? suffix,
}) => InputDecoration(
  labelText: label,
  helperText: helper,
  helperMaxLines: 2,
  prefixText: prefix,
  suffixText: suffix,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
);
