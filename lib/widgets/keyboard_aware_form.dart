import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';

/// Height of the on-screen keyboard over the app, in logical pixels.
///
/// Reads the window as well as the local [MediaQuery]: screens inside the
/// artisan workspace shell sit in a nested Scaffold, and the outer Scaffold
/// removes the keyboard inset from its body's MediaQuery, so those screens
/// would otherwise always see 0.
double keyboardInsetOf(BuildContext context) {
  final local = MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;
  final view = View.maybeOf(context);
  final window = view == null
      ? 0.0
      : view.viewInsets.bottom / view.devicePixelRatio;
  return math.max(local, window);
}

/// Rebuilds [builder] whenever the keyboard opens or closes, including on
/// screens nested in another Scaffold (see [keyboardInsetOf]).
class KeyboardVisibilityBuilder extends StatefulWidget {
  const KeyboardVisibilityBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool keyboardVisible) builder;

  @override
  State<KeyboardVisibilityBuilder> createState() =>
      _KeyboardVisibilityBuilderState();
}

class _KeyboardVisibilityBuilderState extends State<KeyboardVisibilityBuilder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, keyboardInsetOf(context) > 0);
  }
}

/// Slim bar shown just above the keyboard with a "Done" button that closes
/// it. Number and multi-line keyboards have no way to close themselves on
/// iPhone, and the bar takes far less room than a full save bar.
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('keyboard-done-bar'),
      color: AppTheme.scaffoldBg,
      elevation: 4,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton(
            onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Text(
              'Done',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppTheme.terracotta,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the text field being typed in fully visible above the keyboard.
///
/// Wrap a form's scroll view with this. Whenever a text field inside it gets
/// focus, or the keyboard finishes opening, the whole field (label, box and
/// a little margin) is scrolled into view, not just the caret, so a
/// multi-line field is never left half hidden under the app bar.
class RevealFocusedField extends StatefulWidget {
  const RevealFocusedField({super.key, required this.child, this.margin = 16});

  final Widget child;

  /// Extra space kept above and below the field.
  final double margin;

  @override
  State<RevealFocusedField> createState() => _RevealFocusedFieldState();
}

class _RevealFocusedFieldState extends State<RevealFocusedField>
    with WidgetsBindingObserver {
  Timer? _pending;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _pending?.cancel();
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onFocusChanged() => _schedule(const Duration(milliseconds: 60));

  // The keyboard animates in over several metric changes; reveal once it
  // has settled.
  @override
  void didChangeMetrics() => _schedule(const Duration(milliseconds: 150));

  void _schedule(Duration delay) {
    _pending?.cancel();
    _pending = Timer(delay, () {
      if (mounted) _revealFocusedField();
    });
  }

  void _revealFocusedField() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || !focusContext.mounted) return;

    Element? editable;
    Element? field;
    var inside = false;
    focusContext.visitAncestorElements((element) {
      final widget = element.widget;
      if (editable == null && widget is EditableText) editable = element;
      if (field == null && widget is TextField) field = element;
      if (identical(element, context)) {
        inside = true;
        return false;
      }
      return true;
    });
    if (!inside || editable == null) return;

    final target = (field ?? editable)!.findRenderObject();
    if (target is! RenderBox || !target.attached || !target.hasSize) return;
    final Object? viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport is! RenderBox || !viewport.hasSize) return;

    final margin = widget.margin;
    final rect = Rect.fromLTRB(
      0,
      -margin,
      target.size.width,
      target.size.height + margin,
    );
    // Taller than the space left: let the text field keep its caret in view.
    if (rect.height > viewport.size.height) return;
    target.showOnScreen(
      rect: rect,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
