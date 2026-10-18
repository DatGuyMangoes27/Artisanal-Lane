import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../services/artisan_ai_service.dart';
import '../widgets/studio/studio_ai_tools.dart';
import '../widgets/studio/studio_photo_source.dart';
import '../widgets/studio/studio_photo_tool.dart';
import '../widgets/studio/studio_price_tool.dart';
import '../widgets/studio/studio_tip_card.dart';

export '../widgets/studio/studio_photo_source.dart' show StudioPhotoSource;

/// What Listing Studio hands back to the product form. One tool action
/// produces one result; the form applies it straight away.
class ListingAssistantResult {
  final String? title, description;
  final double? price;

  /// Edited or generated photo bytes.
  final Uint8List? photo;

  /// The listing photo [photo] replaces (keeps its position). Null adds
  /// [photo] as a new photo.
  final String? replacesPhotoId;

  const ListingAssistantResult({
    this.title,
    this.description,
    this.price,
    this.photo,
    this.replacesPhotoId,
  });
}

/// The tools Listing Studio offers. AI tools only appear once
/// [artisanAiCapabilitiesProvider] confirms them.
enum StudioTool { photo, price, aiWriting, aiPhoto }

extension on StudioTool {
  String get label => switch (this) {
    StudioTool.photo => 'Photo touch-up',
    StudioTool.price => 'Price calculator',
    StudioTool.aiWriting => 'AI listing text',
    StudioTool.aiPhoto => 'AI styled photo',
  };

  IconData get icon => switch (this) {
    StudioTool.photo => Icons.tune_rounded,
    StudioTool.price => Icons.calculate_outlined,
    StudioTool.aiWriting => Icons.edit_note_rounded,
    StudioTool.aiPhoto => Icons.auto_awesome_outlined,
  };
}

/// Listing Studio: on-device photo touch-up and a cost-based price
/// calculator for a listing, plus AI tools when the account has them.
/// Pops with a single [ListingAssistantResult] when a tool's result is used.
class ListingAssistantScreen extends ConsumerStatefulWidget {
  const ListingAssistantScreen({
    super.key,
    required this.shopId,
    required this.title,
    required this.description,
    this.photos = const [],
    this.initialPhotoIndex = 0,
    this.initialTool = StudioTool.photo,
  });

  final String shopId, title, description;

  /// The listing's current photos, in order.
  final List<StudioPhotoSource> photos;
  final int initialPhotoIndex;
  final StudioTool initialTool;

  @override
  ConsumerState<ListingAssistantScreen> createState() =>
      _ListingAssistantScreenState();
}

class _ListingAssistantScreenState
    extends ConsumerState<ListingAssistantScreen> {
  late StudioTool _tool = widget.initialTool;
  String? _account;
  StudioPhotoSource? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    _account = ref.read(currentUserIdProvider);
    final photos = widget.photos;
    _selectedPhoto = photos.isEmpty
        ? null
        : photos[widget.initialPhotoIndex.clamp(0, photos.length - 1)];
  }

  String get _facts => [
    widget.title,
    widget.description,
  ].where((s) => s.trim().isNotEmpty).join('\n\n');

  void _finish(ListingAssistantResult result) {
    if (ref.read(currentUserIdProvider) != _account || _account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            "You've switched accounts. Reopen your product to keep editing.",
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserIdProvider, (_, value) {
      if (value != _account && mounted) Navigator.of(context).maybePop();
    });
    final caps = watchArtisanAiCapabilities(ref);
    final tools = [
      StudioTool.photo,
      StudioTool.price,
      if (caps.listing) StudioTool.aiWriting,
      if (caps.image) StudioTool.aiPhoto,
    ];
    final current = tools.contains(_tool) ? _tool : StudioTool.photo;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back to your listing',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Listing Studio',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          _ToolSelector(
            tools: tools,
            selected: current,
            onSelected: (tool) {
              HapticFeedback.selectionClick();
              FocusScope.of(context).unfocus();
              setState(() => _tool = tool);
            },
          ),
          const StudioTipCard(),
          Expanded(
            child: IndexedStack(
              sizing: StackFit.expand,
              index: tools.indexOf(current),
              children: [
                for (final tool in tools)
                  KeyedSubtree(
                    key: ValueKey(tool),
                    child: _buildTool(tool),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTool(StudioTool tool) => switch (tool) {
    StudioTool.photo => StudioPhotoTool(
      photos: widget.photos,
      initialIndex: widget.initialPhotoIndex,
      onSelectionChanged: (source) {
        if (mounted && source != _selectedPhoto) {
          setState(() => _selectedPhoto = source);
        }
      },
      onSave: (edited) => _finish(
        ListingAssistantResult(
          photo: edited.bytes,
          replacesPhotoId: edited.sourceId,
        ),
      ),
    ),
    StudioTool.price => StudioPriceTool(
      onUsePrice: (price) => _finish(ListingAssistantResult(price: price)),
    ),
    StudioTool.aiWriting => StudioAiWritingTool(
      shopId: widget.shopId,
      initialFacts: _facts,
      onUseWording: (title, description) => _finish(
        ListingAssistantResult(title: title, description: description),
      ),
    ),
    StudioTool.aiPhoto => StudioAiPhotoTool(
      shopId: widget.shopId,
      facts: _facts,
      source: _selectedPhoto,
      onUsePhoto: (bytes) => _finish(ListingAssistantResult(photo: bytes)),
    ),
  };
}

class _ToolSelector extends StatelessWidget {
  const _ToolSelector({
    required this.tools,
    required this.selected,
    required this.onSelected,
  });

  final List<StudioTool> tools;
  final StudioTool selected;
  final ValueChanged<StudioTool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(13) * 1.5 + 36;
    final height = scaled < 60 ? 60.0 : scaled;
    const padding = EdgeInsets.fromLTRB(16, 8, 16, 8);
    // The two core tools always fit side by side; extra (AI) tools scroll.
    if (tools.length <= 2) {
      return SizedBox(
        height: height,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tools.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _pill(tools[i], expand: true)),
              ],
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _pill(tools[index], expand: false),
      ),
    );
  }

  Widget _pill(StudioTool tool, {required bool expand}) {
    final active = tool == selected;
    final color = active ? AppTheme.terracotta : AppTheme.textPrimary;
    final label = Text(
      tool.label,
      maxLines: 1,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        color: color,
      ),
    );
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('studio-tool-${tool.name}'),
          onTap: () => onSelected(tool),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.terracotta.withValues(alpha: .10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: active
                    ? AppTheme.terracotta
                    : AppTheme.sand.withValues(alpha: .7),
                width: active ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.icon, size: 18, color: color),
                const SizedBox(width: 6),
                expand
                    ? Flexible(
                        child: FittedBox(fit: BoxFit.scaleDown, child: label),
                      )
                    : label,
              ],
            ),
          ),
        ),
      ),
    );
  }
}