import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/models.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/bobgo_vendor_providers.dart';
import '../providers/vendor_providers.dart';
import '../utils/parcel_measurements.dart';
import '../utils/product_form_copy.dart';
import '../utils/vendor_payout_setup.dart';
import '../utils/vendor_subscription_setup.dart';
import '../widgets/parcel_measurements_fields.dart';
import '../widgets/shipping_rates_reference.dart';
import '../widgets/studio/studio_photo_source.dart';
import 'listing_assistant_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  static const _saProvinces = <String>[
    'Eastern Cape',
    'Free State',
    'Gauteng',
    'KwaZulu-Natal',
    'Limpopo',
    'Mpumalanga',
    'Northern Cape',
    'North West',
    'Western Cape',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _compareAtPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _parcelWeightController = TextEditingController();
  final _parcelLengthController = TextEditingController();
  final _parcelWidthController = TextEditingController();
  final _parcelHeightController = TextEditingController();
  String? _parcelError;
  final _careController = TextEditingController();
  final _fragranceController = TextEditingController();
  final _marketPickupNameController = TextEditingController();
  final _marketPickupLocationController = TextEditingController();
  final _optionOneNameController = TextEditingController();
  final _optionTwoNameController = TextEditingController();
  final _optionOneValuesController = TextEditingController();
  final _optionTwoValuesController = TextEditingController();
  final _madeToOrderPriceController = TextEditingController();
  final _leadMinController = TextEditingController();
  final _leadMaxController = TextEditingController();
  final _capacityController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  final Set<String> _selectedTags = {};
  bool _isPublished = true;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isUploading = false;
  bool _hasOptions = false;
  bool _dirty = false;
  bool _draftRestorePrompted = false;
  String? _formError;
  final _scrollController = ScrollController();
  String _fulfillmentMode = 'stocked';
  bool _allowCustomNote = false;
  String? _marketPickupProvince;

  final List<_ProductPhoto> _photos = [];
  List<String> get _imageUrls => _photos
      .where((p) => !p.isPending)
      .map((p) => p.url!)
      .toList(growable: false);
  final List<_VariantDraft> _variants = [];
  List<ShippingOption> _shippingOptions = ShippingOption.defaults();
  final ImagePicker _picker = ImagePicker();
  static const _priceKeyboard = TextInputType.numberWithOptions(decimal: true);
  static final _priceInputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
  ];
  late final Map<String, TextEditingController> _shippingPriceControllers = {
    for (final option in ShippingOption.defaults())
      option.key: TextEditingController(text: option.price.toStringAsFixed(2)),
  };

  bool get _isEditing => widget.productId != null;

  String _imagePickerErrorMessage(ImageSource source) {
    return source == ImageSource.camera
        ? 'Camera access is blocked. Please allow camera access in your phone settings, or choose a photo from your gallery.'
        : 'Could not access your photos. Please allow photo access in your phone settings and try again.';
  }

  String? _requiredPriceValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (tryParseProductPriceText(value) == null) return 'Invalid';
    return null;
  }

  String? _optionalPriceValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (tryParseProductPriceText(value) == null) return 'Invalid';
    return null;
  }

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _titleController,
      _descriptionController,
      _priceController,
      _compareAtPriceController,
      _stockController,
    ]) {
      controller.addListener(() {
        _dirty = true;
        _saveDraft();
      });
    }
    if (_isEditing) {
      _loadProduct();
    } else {
      _hasOptions = false;
      _seedShippingFromShopDefaults();
      _maybeRestoreDraft();
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || _isLoading) return true;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Discard changes?',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "If you leave now, your changes won't be saved.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textHint,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Discard'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Keep editing'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true) await _clearDraft();
    return result ?? false;
  }

  Future<void> _handleClose() async {
    if (_isLoading) return;
    if (await _confirmDiscard() && mounted) context.pop();
  }

  // ── Local draft autosave (new products only) ──────────────────────
  String? get _draftKey {
    final userId = ref.read(currentUserIdProvider);
    return userId == null ? null : 'product_draft_$userId';
  }

  Future<void> _maybeRestoreDraft() async {
    final key = _draftKey;
    if (key == null || _draftRestorePrompted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || !mounted) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _draftRestorePrompted = true;
      final restore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore draft?'),
          content: const Text(
            'You have an unsaved product draft. Continue where you left off?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (restore == true) {
        setState(() {
          _titleController.text = data['title'] as String? ?? '';
          _descriptionController.text = data['description'] as String? ?? '';
          _priceController.text = data['price'] as String? ?? '';
          _compareAtPriceController.text =
              data['compareAtPrice'] as String? ?? '';
          _stockController.text =
              data['stock'] as String? ?? _stockController.text;
          _careController.text = data['care'] as String? ?? '';
          _fragranceController.text = data['fragrance'] as String? ?? '';
          _selectedCategoryId = data['categoryId'] as String?;
          _dirty = true;
        });
      } else {
        await _clearDraft();
      }
    } catch (_) {
      // A corrupt or unreadable draft is simply ignored.
    }
  }

  Future<void> _saveDraft() async {
    if (_isEditing) return;
    final key = _draftKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'price': _priceController.text,
          'compareAtPrice': _compareAtPriceController.text,
          'stock': _stockController.text,
          'care': _careController.text,
          'fragrance': _fragranceController.text,
          'categoryId': _selectedCategoryId,
        }),
      );
    } catch (_) {
      // Local draft saving is best-effort only.
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _clearDraft() async {
    final key = _draftKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      // Nothing to do if this fails; the draft will simply be overwritten.
    }
  }

  void _setHasOptions(bool value) {
    setState(() {
      _hasOptions = value;
      if (value) {
        if (_variants.isEmpty) {
          _variants.add(_VariantDraft.empty());
        }
        if (_optionOneNameController.text.trim().isEmpty) {
          _optionOneNameController.text = defaultProductOptionOneName;
        }
      } else {
        for (final variant in _variants) {
          variant.dispose();
        }
        _variants.clear();
        _optionOneNameController.clear();
        _optionTwoNameController.clear();
        _optionOneValuesController.clear();
        _optionTwoValuesController.clear();
      }
    });
  }

  Future<void> _seedShippingFromShopDefaults() async {
    try {
      final shop = await ref.read(vendorShopProvider.future);
      if (!mounted || shop == null || shop.shippingOptions.isEmpty) return;
      setState(() {
        _shippingOptions = shop.shippingOptions;
        for (final option in _shippingOptions) {
          _shippingPriceControllers[option.key]?.text = option.price
              .toStringAsFixed(2);
        }
        _marketPickupNameController.text =
            _shippingOptions
                .where((option) => option.key == 'market_pickup')
                .firstOrNull
                ?.marketName ??
            '';
        _marketPickupLocationController.text =
            _shippingOptions
                .where((option) => option.key == 'market_pickup')
                .firstOrNull
                ?.marketLocation ??
            '';
        _marketPickupProvince = _shippingOptions
            .where((option) => option.key == 'market_pickup')
            .firstOrNull
            ?.marketProvince;
      });
    } catch (_) {
      // Leave the product form on built-in defaults if the shop defaults fail to load.
    }
  }

  Future<void> _loadProduct() async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final product = await service.getProduct(widget.productId!);
      if (mounted) {
        setState(() => _initFromProduct(product));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(e, fallback: 'Could not load this product.'),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _stockController.dispose();
    _parcelWeightController.dispose();
    _parcelLengthController.dispose();
    _parcelWidthController.dispose();
    _parcelHeightController.dispose();
    _careController.dispose();
    _fragranceController.dispose();
    _marketPickupNameController.dispose();
    _marketPickupLocationController.dispose();
    _optionOneNameController.dispose();
    _optionTwoNameController.dispose();
    _optionOneValuesController.dispose();
    _optionTwoValuesController.dispose();
    _madeToOrderPriceController.dispose();
    _leadMinController.dispose();
    _leadMaxController.dispose();
    _capacityController.dispose();
    for (final controller in _shippingPriceControllers.values) {
      controller.dispose();
    }
    for (final variant in _variants) {
      variant.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _initFromProduct(Product product) {
    if (_isInitialized) return;
    _isInitialized = true;
    _titleController.text = product.title;
    _descriptionController.text = product.description ?? '';
    final pricingFields = pricingFieldsFromStoredValues(
      price: product.price,
      compareAtPrice: product.compareAtPrice,
    );
    _priceController.text = pricingFields.currentPriceText;
    _compareAtPriceController.text = pricingFields.salePriceText;
    _stockController.text = product.stockQty.toString();
    String parcelText(double? v) => v == null ? '' : v.toString();
    _parcelWeightController.text = parcelText(product.shippingWeightKg);
    _parcelLengthController.text = parcelText(product.shippingLengthCm);
    _parcelWidthController.text = parcelText(product.shippingWidthCm);
    _parcelHeightController.text = parcelText(product.shippingHeightCm);
    _selectedCategoryId = product.categoryId;
    _selectedSubcategoryId = product.subcategoryId;
    _selectedTags.addAll(product.tags);
    _isPublished = product.isPublished;
    _careController.text = product.careInstructions ?? '';
    _fragranceController.text = product.fragranceDescription ?? '';
    _fulfillmentMode = product.fulfillmentMode;
    _allowCustomNote = product.allowCustomNote;
    _madeToOrderPriceController.text = product.madeToOrderPrice != null
        ? product.madeToOrderPrice!.toStringAsFixed(2)
        : '';
    _leadMinController.text = product.leadMinDays?.toString() ?? '';
    _leadMaxController.text = product.leadMaxDays?.toString() ?? '';
    _capacityController.text = product.madeToOrderCapacity?.toString() ?? '';
    _photos.addAll(product.images.map(_ProductPhoto.uploaded));
    _shippingOptions = product.shippingOptions.isNotEmpty
        ? product.shippingOptions
        : ShippingOption.defaults();
    for (final option in _shippingOptions) {
      _shippingPriceControllers[option.key]?.text = option.price
          .toStringAsFixed(2);
    }
    _marketPickupNameController.text =
        _shippingOptions
            .where((option) => option.key == 'market_pickup')
            .firstOrNull
            ?.marketName ??
        '';
    _marketPickupLocationController.text =
        _shippingOptions
            .where((option) => option.key == 'market_pickup')
            .firstOrNull
            ?.marketLocation ??
        '';
    _marketPickupProvince = _shippingOptions
        .where((option) => option.key == 'market_pickup')
        .firstOrNull
        ?.marketProvince;
    final optionGroups = product.optionGroups;
    _hasOptions = optionGroups.isNotEmpty;
    if (_hasOptions) {
      _optionOneNameController.text = optionGroups.first.name;
      _optionOneValuesController.text = optionGroups.first.values.join(', ');
      if (optionGroups.length > 1) {
        _optionTwoNameController.text = optionGroups[1].name;
        _optionTwoValuesController.text = optionGroups[1].values.join(', ');
      }
      if (product.variants.isNotEmpty) {
        _variants.addAll(product.variants.map(_VariantDraft.fromVariant));
      } else {
        _variants.add(_VariantDraft.empty());
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Product Photo',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.terracotta,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Use your camera',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.baobab.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.baobab,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Pick from your photos',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickMultipleImages();
                },
              ),
              if (isInternalProductEditorTestMode(
                ref.read(currentUserIdProvider),
              ))
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Use sample product photo'),
                  subtitle: const Text(
                    'Local test only · no gallery access or upload',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _loadSamplePhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSamplePhoto() async {
    if (!isInternalProductEditorTestMode(ref.read(currentUserIdProvider))) {
      return;
    }
    try {
      final bytes = await rootBundle.load('assets/preview/foldaway-tote.jpg');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/artisan-lane-sample.jpg');
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      if (!mounted) return;
      final cropped = await _cropSquare(file.path);
      if (mounted && cropped != null) {
        setState(() {
          _photos.add(_ProductPhoto.pending(cropped));
          _dirty = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load the sample photo. Please try again.'),
          ),
        );
      }
    }
  }

  /// Crops a picked image to a 1:1 square so product photos stay uniform.
  /// Returns the cropped file, or null if the user cancelled the crop.
  Future<File?> _cropSquare(String sourcePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: AppTheme.terracotta,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Crop photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (cropped == null) return null;
      return File(cropped.path);
    } catch (_) {
      // If cropping fails for any reason, fall back to the original image.
      return File(sourcePath);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        final cropped = await _cropSquare(image.path);
        if (cropped != null) {
          setState(() {
            _photos.add(_ProductPhoto.pending(cropped));
            _dirty = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_imagePickerErrorMessage(source)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Imports every selected photo immediately; cropping is an optional,
  /// per-photo action from the thumbnail rather than a forced screen.
  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (images.isNotEmpty && mounted) {
        setState(() {
          _photos.addAll(
            images.map((x) => _ProductPhoto.pending(File(x.path))),
          );
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Crops a single pending photo in place, keeping its position in order.
  Future<void> _editPhotoCrop(_ProductPhoto photo) async {
    if (!photo.isPending || photo.file == null) return;
    final cropped = await _cropSquare(photo.file!.path);
    if (cropped != null && mounted) {
      setState(() {
        photo.file = cropped;
        _dirty = true;
      });
    }
  }

  void _removePhoto(_ProductPhoto photo) {
    setState(() {
      _photos.removeWhere((p) => p.id == photo.id);
      _dirty = true;
    });
  }

  /// [newIndex] is the position after removing the dragged photo; keep it
  /// before the trailing add tile.
  void _reorderPhoto(int oldIndex, int newIndex) {
    setState(() {
      _dirty = true;
      final photo = _photos.removeAt(oldIndex);
      _photos.insert(newIndex.clamp(0, _photos.length), photo);
    });
  }

  /// Opens Listing Studio (photo touch-up, price calculator and, when the
  /// account has them, AI tools) and applies whatever it hands back.
  Future<void> _openListingStudio({int photoIndex = 0}) async {
    final user = ref.read(currentUserIdProvider);
    try {
      final shop = await ref.read(vendorShopProvider.future);
      if (!mounted || shop == null || user != ref.read(currentUserIdProvider)) {
        return;
      }
      final sources = [
        for (final photo in _photos)
          photo.isPending
              ? StudioPhotoSource.file('${photo.id}', photo.file!)
              : StudioPhotoSource(
                  id: '${photo.id}',
                  thumbnail: CachedNetworkImageProvider(photo.url!),
                  loadBytes: () => loadNetworkPhotoBytes(photo.url!),
                ),
      ];
      final result = await Navigator.of(context).push<ListingAssistantResult>(
        MaterialPageRoute(
          builder: (_) => ListingAssistantScreen(
            shopId: shop.id,
            title: _titleController.text,
            description: _descriptionController.text,
            photos: sources,
            initialPhotoIndex: photoIndex,
          ),
        ),
      );
      if (!mounted ||
          result == null ||
          user != ref.read(currentUserIdProvider)) {
        return;
      }
      File? edited;
      final bytes = result.photo;
      if (bytes != null) {
        final directory = await getTemporaryDirectory();
        edited = File(
          '${directory.path}/listing-studio-${DateTime.now().microsecondsSinceEpoch}.png',
        );
        await edited.writeAsBytes(bytes, flush: true);
      }
      if (!mounted || user != ref.read(currentUserIdProvider)) return;
      final messenger = ScaffoldMessenger.of(context);
      String? message;
      setState(() {
        if (result.title != null) _titleController.text = result.title!;
        if (result.description != null) {
          _descriptionController.text = result.description!;
        }
        if (result.price != null) {
          _priceController.text = result.price!.toStringAsFixed(2);
          message = 'Price set to R${result.price!.toStringAsFixed(2)}.';
        }
        if (result.title != null || result.description != null) {
          message = 'Wording added to your listing.';
        }
        if (edited != null) {
          final placed = placeStudioPhoto<_ProductPhoto>(
            _photos,
            edited: _ProductPhoto.pending(edited),
            isSource: (p) =>
                result.replacesPhotoId != null &&
                '${p.id}' == result.replacesPhotoId,
          );
          if (placed == null) {
            message =
                'Remove a photo first. A listing can have up to 8 photos.';
          } else {
            final replaced = placed.length == _photos.length;
            _photos
              ..clear()
              ..addAll(placed);
            message = replaced
                ? 'Edited photo saved to your listing.'
                : 'Photo added to your listing.';
          }
        }
        _dirty = true;
      });
      if (message != null) {
        HapticFeedback.mediumImpact();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(message!),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Could not open Listing Studio. Your listing is unchanged.',
            ),
          ),
        );
      }
    }
  }

  /// The one entry point to Listing Studio, shown under the photo strip.
  Widget _buildStudioEntry({required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('open-listing-studio'),
          onTap: enabled ? _openListingStudio : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.sand.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.bone,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.terracotta,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Listing Studio',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Touch up your photos and work out a fair price.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoPreview({
    required ImageProvider image,
    required String label,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.72,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 14,
                right: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close photo preview',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 14,
                left: 16,
                right: 16,
                child: Text(
                  'Pinch or drag to inspect the crop',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingReadiness() {
    final checks =
        <({bool complete, IconData icon, String title, String detail})>[
          (
            complete: _photos.isNotEmpty,
            icon: Icons.photo_outlined,
            title: 'Photos',
            detail: 'Add at least one clear, square product photo.',
          ),
          (
            complete: _titleController.text.trim().isNotEmpty,
            icon: Icons.title_rounded,
            title: 'Name',
            detail: 'Give the piece a clear, buyer-friendly title.',
          ),
          (
            complete: _descriptionController.text.trim().isNotEmpty,
            icon: Icons.subject_rounded,
            title: 'Story',
            detail: 'Share material, making process, size, or care details.',
          ),
          (
            complete: _selectedCategoryId != null,
            icon: Icons.category_outlined,
            title: 'Category',
            detail: 'Choose where shoppers should discover it.',
          ),
        ];
    final completed = checks.where((check) => check.complete).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      color: AppTheme.cardBg,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.sand.withValues(alpha: 0.55)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.terracotta.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            color: AppTheme.terracotta,
          ),
        ),
        title: Text(
          'Listing check: $completed/${checks.length}',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          'A simple guide while you build your listing.',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
        ),
        children: [
          ...checks.map(
            (check) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    check.complete ? Icons.check_circle_rounded : check.icon,
                    color: check.complete ? AppTheme.baobab : AppTheme.textHint,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(
                            text: '${check.title}: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: check.detail),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addVariant() {
    setState(() => _variants.add(_VariantDraft.empty()));
  }

  List<String> _parseOptionValues(String raw) {
    final seen = <String>{};
    final values = <String>[];
    for (final piece in raw.split(RegExp(r'[\n,]'))) {
      final trimmed = piece.trim();
      final normalized = trimmed.toLowerCase();
      if (trimmed.isEmpty || !seen.add(normalized)) {
        continue;
      }
      values.add(trimmed);
    }
    return values;
  }

  String _variantKeyFromValues(String optionOneValue, String optionTwoValue) {
    final second = optionTwoValue.trim();
    return second.isEmpty
        ? optionOneValue.trim().toLowerCase()
        : '${optionOneValue.trim().toLowerCase()}|${second.toLowerCase()}';
  }

  String _variantKey(_VariantDraft variant) => _variantKeyFromValues(
    variant.optionOneController.text,
    variant.optionTwoController.text,
  );

  bool _isBlankVariantDraft(_VariantDraft variant) {
    return variant.optionOneController.text.trim().isEmpty &&
        variant.optionTwoController.text.trim().isEmpty &&
        variant.priceController.text.trim().isEmpty &&
        variant.compareAtPriceController.text.trim().isEmpty &&
        variant.stockController.text.trim() == '0' &&
        variant.imageUrls.isEmpty &&
        variant.pendingFiles.isEmpty;
  }

  _VariantDraft _newGeneratedVariant({
    required String optionOneValue,
    required String optionTwoValue,
  }) {
    _VariantDraft? seed;
    for (final variant in _variants) {
      if (!_isBlankVariantDraft(variant)) {
        seed = variant;
        break;
      }
    }

    return _VariantDraft(
      optionOneController: TextEditingController(text: optionOneValue),
      optionTwoController: TextEditingController(text: optionTwoValue),
      priceController: TextEditingController(
        text: (seed?.priceController.text.trim().isNotEmpty ?? false)
            ? seed?.priceController.text.trim() ?? ''
            : _priceController.text.trim(),
      ),
      compareAtPriceController: TextEditingController(
        text: (seed?.compareAtPriceController.text.trim().isNotEmpty ?? false)
            ? seed?.compareAtPriceController.text.trim() ?? ''
            : _compareAtPriceController.text.trim(),
      ),
      stockController: TextEditingController(
        text: (seed?.stockController.text.trim().isNotEmpty ?? false)
            ? seed?.stockController.text.trim() ?? '0'
            : '0',
      ),
    );
  }

  void _generateCombinations() {
    final optionOneName = _optionOneNameController.text.trim();
    final optionTwoName = _optionTwoNameController.text.trim();
    final optionOneValues = _parseOptionValues(_optionOneValuesController.text);
    final optionTwoValues = _parseOptionValues(_optionTwoValuesController.text);

    if (optionOneName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add the first option name before generating combinations.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (optionOneValues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one value for the first option.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (optionTwoName.isNotEmpty && optionTwoValues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one value for the second option.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final existingByKey = <String, _VariantDraft>{};
    final unmatchedExisting = <_VariantDraft>[];
    for (final variant in _variants) {
      final key = _variantKey(variant);
      if (key.isEmpty || _isBlankVariantDraft(variant)) {
        variant.dispose();
        continue;
      }
      existingByKey[key] = variant;
    }

    final generated = <_VariantDraft>[];
    for (final optionOneValue in optionOneValues) {
      if (optionTwoName.isEmpty) {
        final key = _variantKeyFromValues(optionOneValue, '');
        generated.add(
          existingByKey.remove(key) ??
              _newGeneratedVariant(
                optionOneValue: optionOneValue,
                optionTwoValue: '',
              ),
        );
        continue;
      }

      for (final optionTwoValue in optionTwoValues) {
        final key = _variantKeyFromValues(optionOneValue, optionTwoValue);
        generated.add(
          existingByKey.remove(key) ??
              _newGeneratedVariant(
                optionOneValue: optionOneValue,
                optionTwoValue: optionTwoValue,
              ),
        );
      }
    }

    unmatchedExisting.addAll(existingByKey.values);

    setState(() {
      _variants
        ..clear()
        ..addAll(generated)
        ..addAll(unmatchedExisting);
    });

    final generatedCount = generated.length;
    final preservedCount = unmatchedExisting.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          preservedCount > 0
              ? 'Generated $generatedCount combinations. Kept $preservedCount unmatched existing row(s) below.'
              : 'Generated $generatedCount combinations.',
        ),
        backgroundColor: AppTheme.baobab,
      ),
    );
  }

  void _removeVariant(int index) {
    if (_variants.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one option for this product.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final variant = _variants.removeAt(index);
    variant.dispose();
    setState(() {});
  }

  Future<void> _pickVariantImages(
    int index, {
    required bool multiple,
    ImageSource? source,
  }) async {
    try {
      if (multiple) {
        final images = await _picker.pickMultiImage(
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );
        if (images.isNotEmpty) {
          for (final image in images) {
            final cropped = await _cropSquare(image.path);
            if (cropped != null) {
              setState(() => _variants[index].pendingFiles.add(cropped));
            }
          }
        }
        return;
      }

      final image = await _picker.pickImage(
        source: source ?? ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        final cropped = await _cropSquare(image.path);
        if (cropped != null) {
          setState(() => _variants[index].pendingFiles.add(cropped));
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _imagePickerErrorMessage(source ?? ImageSource.gallery),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showVariantImageSourcePicker(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Option Photos',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.terracotta,
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVariantImages(
                    index,
                    multiple: false,
                    source: ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.baobab,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVariantImages(index, multiple: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadVariantPendingImages() async {
    final service = ref.read(supabaseServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    for (final variant in _variants) {
      if (variant.pendingFiles.isEmpty) continue;
      for (final file in variant.pendingFiles) {
        final url = await service.uploadProductImage(userId, file);
        variant.imageUrls.add(url);
      }
      variant.pendingFiles.clear();
    }
  }

  String? _validateVariants() {
    if (_variants.isEmpty) {
      return 'Add at least one option.';
    }

    final optionOneName = _optionOneNameController.text.trim();
    final optionTwoName = _optionTwoNameController.text.trim();
    if (optionOneName.isEmpty) {
      return 'Add a first option name, like Size or Colour.';
    }

    final seenCombinations = <String>{};

    for (final variant in _variants) {
      final optionOneValue = variant.optionOneController.text.trim();
      final optionTwoValue = variant.optionTwoController.text.trim();

      if (optionOneValue.isEmpty) {
        return 'Each combination needs a ${optionOneName.toLowerCase()} value.';
      }
      if (optionTwoName.isNotEmpty && optionTwoValue.isEmpty) {
        return 'Each combination needs a ${optionTwoName.toLowerCase()} value.';
      }
      if (optionTwoName.isEmpty && optionTwoValue.isNotEmpty) {
        return 'Add a second option name before using a second option value.';
      }

      final key = optionTwoName.isEmpty
          ? optionOneValue.toLowerCase()
          : '${optionOneValue.toLowerCase()}|${optionTwoValue.toLowerCase()}';
      if (!seenCombinations.add(key)) {
        return 'Each option combination must be unique.';
      }
      if (tryParseProductPriceText(variant.priceController.text) == null) {
        return 'Each combination needs a valid price.';
      }
      if (int.tryParse(variant.stockController.text.trim()) == null) {
        return 'Each combination needs a valid stock quantity.';
      }
      if (variant.imageUrls.isEmpty && variant.pendingFiles.isEmpty) {
        return 'Each combination needs at least one photo.';
      }
    }

    return null;
  }

  Future<void> _uploadPendingImages() async {
    final pending = _photos.where((p) => p.isPending).toList();
    if (pending.isEmpty) return;
    final service = ref.read(supabaseServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Upload in place so the artisan's chosen order and cover photo survive.
    for (final photo in pending) {
      final url = await service.uploadProductImage(userId, photo.file!);
      photo.url = url;
    }
  }

  Future<void> _save() async {
    // The private device-validation mode deliberately never reaches uploads or
    // product persistence, even if a control is triggered programmatically.
    if (isInternalProductEditorTestMode(ref.read(currentUserIdProvider))) {
      return;
    }
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _formError = 'Please fix the highlighted fields below.');
      _scrollToTop();
      return;
    }
    if (_hasOptions) {
      final variantError = _validateVariants();
      if (variantError != null) {
        setState(() => _formError = variantError);
        _scrollToTop();
        return;
      }
    }
    if (_photos.isEmpty &&
        _variants.every(
          (variant) =>
              variant.imageUrls.isEmpty && variant.pendingFiles.isEmpty,
        )) {
      setState(() => _formError = 'Please add at least one product photo');
      _scrollToTop();
      return;
    }
    final parcel = parseParcelMeasurements(
      weightKg: _parcelWeightController.text,
      lengthCm: _parcelLengthController.text,
      widthCm: _parcelWidthController.text,
      heightCm: _parcelHeightController.text,
    );
    if (parcel.error != null) {
      setState(() {
        _parcelError = parcel.error;
        _formError = parcel.error;
      });
      _scrollToTop();
      return;
    }
    _parcelError = null;
    final productShippingOptions = _buildProductShippingOptions();
    if (!productShippingOptions.any((option) => option.enabled)) {
      setState(
        () => _formError =
            'Enable at least one shipping option for this product.',
      );
      _scrollToTop();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hasPendingPhotos = _photos.any((p) => p.isPending);
      if (hasPendingPhotos ||
          _variants.any((variant) => variant.pendingFiles.isNotEmpty)) {
        setState(() => _isUploading = true);
      }
      if (hasPendingPhotos) {
        await _uploadPendingImages();
      }
      await _uploadVariantPendingImages();
      setState(() => _isUploading = false);

      final service = ref.read(supabaseServiceProvider);
      final shop = await ref.read(vendorShopProvider.future);
      if (shop == null) throw Exception("Your shop isn't set up yet. Please contact Artisan Lane support.");

      final List<Map<String, dynamic>> variantPayloads;
      final List<Map<String, dynamic>> optionGroups;
      final List<String> coverImages;
      final ProductPricingValues summaryPricing;
      final int fallbackStock;

      if (_hasOptions) {
        final optionOneName = _optionOneNameController.text.trim();
        final optionTwoName = _optionTwoNameController.text.trim();

        variantPayloads = _variants.asMap().entries.map((entry) {
          final variant = entry.value;
          final optionValues = <String>[
            variant.optionOneController.text.trim(),
            if (optionTwoName.isNotEmpty)
              variant.optionTwoController.text.trim(),
          ];
          final displayName = optionValues.join(' / ');
          final variantPricing = normalizeProductPricingForSave(
            currentPriceText: variant.priceController.text.trim(),
            salePriceText: variant.compareAtPriceController.text.trim(),
          );
          return <String, dynamic>{
            if (variant.id != null) 'id': variant.id,
            'display_name': displayName,
            'color_name': optionValues.length == 1
                ? optionValues.first
                : displayName,
            'option_values': optionValues,
            'price': variantPricing.price,
            'compare_at_price': variantPricing.compareAtPrice,
            'stock_qty': int.parse(variant.stockController.text.trim()),
            'images': List<String>.from(variant.imageUrls),
            'is_active': true,
            'sort_order': entry.key,
          };
        }).toList();

        optionGroups = <Map<String, dynamic>>[
          {
            'name': optionOneName,
            'values': _variants
                .map((variant) => variant.optionOneController.text.trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList(),
          },
          if (optionTwoName.isNotEmpty)
            {
              'name': optionTwoName,
              'values': _variants
                  .map((variant) => variant.optionTwoController.text.trim())
                  .where((value) => value.isNotEmpty)
                  .toSet()
                  .toList(),
            },
        ];

        coverImages = _imageUrls.isNotEmpty
            ? _imageUrls
            : List<String>.from(variantPayloads.first['images'] as List);
        summaryPricing = productSummaryPricingForSave(
          hasOptions: true,
          currentPriceText: _priceController.text,
          salePriceText: _compareAtPriceController.text,
          firstVariantPricing: ProductPricingValues(
            price: (variantPayloads.first['price'] as num).toDouble(),
            compareAtPrice: (variantPayloads.first['compare_at_price'] as num?)
                ?.toDouble(),
          ),
        );
        fallbackStock =
            (_stockController.text.trim().isNotEmpty
                ? int.tryParse(_stockController.text.trim())
                : null) ??
            _variants.fold<int>(
              0,
              (sum, variant) =>
                  sum + int.parse(variant.stockController.text.trim()),
            );
      } else {
        summaryPricing = productSummaryPricingForSave(
          hasOptions: false,
          currentPriceText: _priceController.text.trim(),
          salePriceText: _compareAtPriceController.text.trim(),
        );
        variantPayloads = const <Map<String, dynamic>>[];
        optionGroups = const <Map<String, dynamic>>[];
        coverImages = List<String>.from(_imageUrls);
        fallbackStock = int.parse(_stockController.text.trim());
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': summaryPricing.price,
        'stock_qty': fallbackStock,
        'is_published': _isPublished,
        'images': coverImages,
        'option_groups': optionGroups,
        'tags': _selectedTags.toList(),
        'shipping_options': productShippingOptions
            .map((option) => option.toJson())
            .toList(),
        ...parcel.measurements.toProductJson(),
        'variants': variantPayloads,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
        'subcategory_id': _selectedSubcategoryId,
        'compare_at_price': summaryPricing.compareAtPrice,
        if (_careController.text.trim().isNotEmpty)
          'care_instructions': _careController.text.trim(),
        'fragrance_description': _fragranceController.text.trim().isNotEmpty
            ? _fragranceController.text.trim()
            : null,
        'fulfillment_mode': _fulfillmentMode,
        'made_to_order_price':
            _madeToOrderPriceController.text.trim().isNotEmpty
            ? tryParseProductPriceText(_madeToOrderPriceController.text)
            : null,
        'made_to_order_lead_min_days': int.tryParse(
          _leadMinController.text.trim(),
        ),
        'made_to_order_lead_max_days': int.tryParse(
          _leadMaxController.text.trim(),
        ),
        'made_to_order_capacity': int.tryParse(_capacityController.text.trim()),
        'made_to_order_allow_custom_note': _allowCustomNote,
      };

      if (_isEditing) {
        await service.updateProduct(widget.productId!, data);
      } else {
        await service.createProduct(shop.id, data);
      }

      ref.invalidate(vendorProductsProvider);
      _dirty = false;
      await _clearDraft();
      if (mounted) {
        HapticFeedback.mediumImpact();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Product updated' : 'Product created'),
            backgroundColor: AppTheme.baobab,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteProduct() async {
    final titleRaw = _titleController.text.trim();
    final displayTitle = titleRaw.isEmpty ? 'this product' : titleRaw;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.delete_forever_rounded,
              color: AppTheme.error,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete $displayTitle?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'The listing will be removed from your store and the marketplace. Any past orders containing this product stay intact for your records.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.deleteProduct(widget.productId!);
      ref.invalidate(vendorProductsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$displayTitle deleted.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.baobab,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete product: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String get _fallbackCurrentPriceLabel =>
      currentPriceLabelForSalePrice(_compareAtPriceController.text);

  String _variantCurrentPriceLabel(_VariantDraft variant) =>
      currentPriceLabelForSalePrice(variant.compareAtPriceController.text);

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(vendorCategoriesProvider);
    final payoutProfile =
        ref.watch(vendorPayoutProfileStreamProvider).value ??
        ref.watch(vendorPayoutProfileProvider).value;
    final payoutReady = isVendorPayoutSetupComplete(payoutProfile);
    final subscription = preferredVendorSubscription(
      streamValue: ref.watch(vendorSubscriptionStreamProvider).value,
      futureValue: ref.watch(vendorSubscriptionProvider).value,
    );
    final subscriptionActive = isVendorSubscriptionActive(subscription);
    final internalEditorTestMode = isInternalProductEditorTestMode(
      ref.watch(currentUserIdProvider),
    );

    final totalImages = _photos.length;

    if (_isEditing && !_isInitialized) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scaffoldBg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Edit Product',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.terracotta,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (!_isEditing && !subscriptionActive && !internalEditorTestMode) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scaffoldBg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'New Product',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    size: 36,
                    color: AppTheme.terracotta,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start your artisan subscription first',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    vendorSubscriptionGateMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Open subscription',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () =>
                        context.push('/vendor/profile/subscription'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isEditing && !payoutReady && !internalEditorTestMode) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scaffoldBg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'New Product',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    size: 36,
                    color: AppTheme.terracotta,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Complete payout details first',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    vendorPayoutGateMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Open payout details',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => context.push('/vendor/profile/payouts'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isLoading && !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isLoading) return;
        if (await _confirmDiscard() && mounted) this.context.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scaffoldBg,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            tooltip: 'Close',
            onPressed: _isLoading ? null : _handleClose,
          ),
          title: Text(
            _isEditing ? 'Edit Product' : 'New Product',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
          ),
          actions: _isEditing
              ? [
                  IconButton(
                    tooltip: 'Delete product',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                    ),
                    onPressed: _isLoading || internalEditorTestMode
                        ? null
                        : _confirmDeleteProduct,
                  ),
                  const SizedBox(width: 4),
                ]
              : null,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              if (_formError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formError!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (internalEditorTestMode) ...[
                Container(
                  key: const Key('internal-product-editor-test-mode'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.sand.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.baobab.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Internal product-editor test mode: local photo tools only. '
                    'Publishing and saving are disabled.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (creatorCommerceEnabled) ...[
                _buildListingReadiness(),
                const SizedBox(height: 20),
              ],

              // ── Photos section ──────────────────────────────────
              _buildLabel(_hasOptions ? 'Fallback Photos' : 'Product Photos'),
              const SizedBox(height: 4),
              Text(
                _hasOptions
                    ? '$totalImages/8 photos added · used when no option photos are set · drag to reorder · first photo is the cover'
                    : '$totalImages/8 photos added · drag to reorder · first photo is the cover',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textHint,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  itemCount: _photos.length + (totalImages < 8 ? 1 : 0),
                  onReorderItem: (oldIndex, newIndex) {
                    if (oldIndex >= _photos.length) return;
                    _reorderPhoto(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    if (index == _photos.length) {
                      return GestureDetector(
                        key: const ValueKey('add-product-photo'),
                        onTap: _showImageSourcePicker,
                        child: Container(
                          width: 110,
                          height: 110,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.sand,
                              width: 1.5,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.baobab.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_a_photo_rounded,
                                  color: AppTheme.baobab,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Photo',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.baobab,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final photo = _photos[index];
                    return _ImageTile(
                      key: ValueKey('photo-${photo.id}'),
                      index: index,
                      isCover: index == 0,
                      onRemove: () => _removePhoto(photo),
                      onPreview: () => _showPhotoPreview(
                        image: photo.isPending
                            ? FileImage(photo.file!)
                            : CachedNetworkImageProvider(photo.url!),
                        label: photo.isPending
                            ? 'New product photo ${index + 1}'
                            : 'Product photo ${index + 1}',
                      ),
                      onEdit: photo.isPending
                          ? () => _editPhotoCrop(photo)
                          : null,
                      isPending: photo.isPending,
                      child: photo.isPending
                          ? Image.file(photo.file!, fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: photo.url!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: AppTheme.textHint,
                              ),
                            ),
                    );
                  },
                ),
              ),
              _buildStudioEntry(enabled: !_isLoading && !_isUploading),
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.baobab,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Uploading photos...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.baobab,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // ── Title ───────────────────────────────────────────
              _buildLabel('Product Title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                decoration: const InputDecoration(hintText: 'Handwoven Basket'),
              ),
              const SizedBox(height: 20),

              _buildLabel('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Describe your product...',
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('Category'),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<String>(
                  key: const Key('product-category'),
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    hintText: 'Select category',
                  ),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name,
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedCategoryId = v;
                    _selectedSubcategoryId = null;
                    _selectedTags.clear();
                  }),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load categories'),
              ),
              const SizedBox(height: 20),

              // Subcategory
              if (_selectedCategoryId != null) ...[
                _buildLabel('Subcategory'),
                const SizedBox(height: 8),
                _buildSubcategoryDropdown(),
                const SizedBox(height: 20),
              ],

              // Tags (category-specific filters)
              if (_selectedCategoryId != null) ...[
                Builder(
                  builder: (context) {
                    final cats = ref.read(vendorCategoriesProvider).value ?? [];
                    final cat = cats
                        .where((c) => c.id == _selectedCategoryId)
                        .firstOrNull;
                    final tags = cat?.availableFilterTags ?? [];
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Tags'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tags.map((tag) {
                            final selected = _selectedTags.contains(tag);
                            return FilterChip(
                              label: Text(
                                tag[0].toUpperCase() + tag.substring(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              selected: selected,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                              selectedColor: AppTheme.terracotta,
                              checkmarkColor: Colors.white,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: selected
                                    ? AppTheme.terracotta
                                    : AppTheme.sand.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ],

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasOptions
                        ? AppTheme.terracotta.withValues(alpha: 0.35)
                        : AppTheme.sand.withValues(alpha: 0.4),
                  ),
                ),
                // ListTiles need their own Material inside a decorated box so
                // ink splashes render (and the framework assertion stays quiet).
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(14),
                  child: SwitchListTile(
                    value: _hasOptions,
                    onChanged: (value) => _setHasOptions(value),
                    title: Text(
                      'This product has multiple options',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _hasOptions
                          ? 'Set up sizes, colours or other combinations below.'
                          : 'Off by default — turn on if this product comes in variations like size or colour.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                        height: 1.4,
                      ),
                    ),
                    activeTrackColor: AppTheme.terracotta,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_hasOptions) ...[
                _buildLabel('Product Options'),
                const SizedBox(height: 8),
                Text(
                  productOptionsHelperText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _optionOneNameController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Primary option name',
                          hintText: defaultProductOptionOneName,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _optionTwoNameController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Second option name',
                          hintText: defaultProductOptionTwoName,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _optionOneValuesController,
                        minLines: 2,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText:
                              _optionOneNameController.text.trim().isEmpty
                              ? 'Option 1 Values'
                              : '${_optionOneNameController.text.trim()} Values',
                          hintText: defaultProductOptionOneValuesHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _optionTwoValuesController,
                        minLines: 2,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText:
                              _optionTwoNameController.text.trim().isEmpty
                              ? 'Option 2 Values'
                              : '${_optionTwoNameController.text.trim()} Values',
                          hintText: defaultProductOptionTwoValuesHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter values separated by commas or new lines, then generate the combinations below. You can keep Size and Color or rename them if this product needs different options.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _generateCombinations,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Generate Combinations'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.terracotta,
                        side: BorderSide(
                          color: AppTheme.terracotta.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._variants.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildVariantCard(entry.key, entry.value),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addVariant,
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppTheme.terracotta,
                    ),
                    label: Text(
                      'Add Another Combination',
                      style: GoogleFonts.poppins(
                        color: AppTheme.terracotta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(_fallbackCurrentPriceLabel),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: _priceKeyboard,
                          inputFormatters: _priceInputFormatters,
                          validator: (v) {
                            if (_hasOptions) return null;
                            return _requiredPriceValidator(v);
                          },
                          decoration: InputDecoration(
                            hintText: _hasOptions
                                ? 'Optional when variants are set'
                                : 'What buyers pay',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(salePriceFieldLabel),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _compareAtPriceController,
                          keyboardType: _priceKeyboard,
                          inputFormatters: _priceInputFormatters,
                          validator: _optionalPriceValidator,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Optional discounted price',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildLabel(
                _hasOptions ? 'Fallback Stock Quantity' : 'Stock Quantity',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (_hasOptions) return null;
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Invalid';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: _hasOptions
                      ? 'Optional when variants are set'
                      : 'How many you have in stock',
                ),
              ),
              const SizedBox(height: 20),

              _buildFulfillmentSection(),
              const SizedBox(height: 20),

              _buildProductShippingSection(),
              const SizedBox(height: 20),

              // ── Care Instructions ────────────────────────────────
              _buildCareSection(),
              const SizedBox(height: 16),

              // ── Fragrance Options ────────────────────────────────
              _buildFragranceSection(),
              const SizedBox(height: 20),

              SwitchListTile(
                value: internalEditorTestMode ? false : _isPublished,
                onChanged: internalEditorTestMode
                    ? null
                    : (v) => setState(() => _isPublished = v),
                title: Text(
                  'Publish',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  internalEditorTestMode
                      ? 'Disabled for this local validation session'
                      : _isPublished
                      ? 'Visible to buyers'
                      : 'Saved as draft',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
                activeTrackColor: AppTheme.baobab,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              border: Border(
                top: BorderSide(color: AppTheme.sand.withValues(alpha: 0.4)),
              ),
            ),
            child: GradientButton(
              label: internalEditorTestMode
                  ? 'Saving disabled in test mode'
                  : _isEditing
                  ? 'Save Changes'
                  : 'Create Product',
              isLoading: _isLoading,
              onPressed: _isLoading || internalEditorTestMode ? null : _save,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFulfillmentSection() {
    final showMtoFields = _fulfillmentMode != 'stocked';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Fulfillment'),
        const SizedBox(height: 4),
        Text(
          'Made-to-order items stay buyable even when stock runs out.',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _fulfillmentMode,
          items: const [
            DropdownMenuItem(value: 'stocked', child: Text('Stocked only')),
            DropdownMenuItem(
              value: 'made_to_order',
              child: Text('Made to order only'),
            ),
            DropdownMenuItem(
              value: 'stocked_with_mto',
              child: Text('Stocked, then made to order'),
            ),
          ],
          onChanged: (value) =>
              setState(() => _fulfillmentMode = value ?? 'stocked'),
        ),
        if (showMtoFields) ...[
          const SizedBox(height: 16),
          _buildLabel('Made-to-order price (optional)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _madeToOrderPriceController,
            keyboardType: _priceKeyboard,
            inputFormatters: _priceInputFormatters,
            decoration: const InputDecoration(
              hintText: 'Defaults to the price above',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Lead time min (days)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _leadMinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'e.g. 14'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Lead time max (days)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _leadMaxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'e.g. 21'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('Open made-to-order capacity (optional)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _capacityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Leave blank for unlimited',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _allowCustomNote,
            onChanged: (v) => setState(() => _allowCustomNote = v),
            title: Text(
              'Allow custom request note',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Buyers can describe their custom order',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
            activeTrackColor: AppTheme.baobab,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }

  Widget _buildCareSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.terracotta, AppTheme.baobab],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: Text(
            'Care Instructions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            'Optional · helps buyers look after their item',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
          ),
          children: [
            TextFormField(
              controller: _careController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'e.g. Hand wash in cold water. Do not bleach. Air dry flat. Store in a cool dry place away from direct sunlight.',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textHint,
                ),
                hintMaxLines: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFragranceSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.terracotta, AppTheme.baobab],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_florist_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: Text(
            'Fragrance Options',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            'Optional · for candles, soaps, creams & other scented goods',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
          ),
          children: [
            TextFormField(
              controller: _fragranceController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'e.g. Lavender & chamomile, vanilla bean, rooibos. Describe the fragrances buyers can choose from.',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textHint,
                ),
                hintMaxLines: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ShippingOption> _buildProductShippingOptions() {
    final marketPickupName = _marketPickupNameController.text.trim();
    final marketPickupLocation = _marketPickupLocationController.text.trim();
    final marketPickupProvince = _marketPickupProvince?.trim() ?? '';
    return _shippingOptions
        .map((option) {
          final rawPrice =
              _shippingPriceControllers[option.key]?.text.trim() ?? '';
          final parsedPrice = tryParseProductPriceText(rawPrice);
          return option.copyWith(
            price: parsedPrice ?? option.price,
            marketName: option.key == 'market_pickup'
                ? (marketPickupName.isEmpty ? null : marketPickupName)
                : null,
            marketLocation: option.key == 'market_pickup'
                ? (marketPickupLocation.isEmpty ? null : marketPickupLocation)
                : null,
            marketProvince: option.key == 'market_pickup'
                ? (marketPickupProvince.isEmpty ? null : marketPickupProvince)
                : null,
          );
        })
        .toList(growable: false);
  }

  Widget _buildProductShippingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Shipping For This Product'),
        const SizedBox(height: 8),
        Text(
          'Choose which delivery methods buyers can use for this product and set the price for each one.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppTheme.textHint,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        const ShippingRatesReferenceCard(),
        const SizedBox(height: 12),
        ..._shippingOptions.map(_buildProductShippingOptionCard),
        if (ref.watch(bobGoServerEnabledProvider).asData?.value ?? false) ...[
          const SizedBox(height: 16),
          ParcelMeasurementsFields(
            weightController: _parcelWeightController,
            lengthController: _parcelLengthController,
            widthController: _parcelWidthController,
            heightController: _parcelHeightController,
            errorText: _parcelError,
          ),
        ],
      ],
    );
  }

  Widget _buildProductShippingOptionCard(ShippingOption option) {
    final isEnabled = option.enabled;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled
              ? AppTheme.terracotta.withValues(alpha: 0.3)
              : AppTheme.sand.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? AppTheme.terracotta.withValues(alpha: 0.1)
                        : AppTheme.bone,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    option.icon,
                    size: 20,
                    color: isEnabled ? AppTheme.terracotta : AppTheme.textHint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? AppTheme.textPrimary
                              : AppTheme.textHint,
                        ),
                      ),
                      Text(
                        option.description,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (value) {
                    setState(() {
                      _shippingOptions = _shippingOptions
                          .map(
                            (entry) => entry.key == option.key
                                ? entry.copyWith(enabled: value)
                                : entry,
                          )
                          .toList(growable: false);
                    });
                  },
                  activeThumbColor: AppTheme.terracotta,
                  activeTrackColor: AppTheme.terracotta.withValues(alpha: 0.2),
                  inactiveThumbColor: AppTheme.textHint,
                  inactiveTrackColor: AppTheme.bone,
                ),
              ],
            ),
          ),
          if (isEnabled) ...[
            Divider(height: 1, color: AppTheme.sand.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Price',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'R',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: _shippingPriceControllers[option.key],
                          keyboardType: _priceKeyboard,
                          inputFormatters: _priceInputFormatters,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          validator: (value) {
                            if (!isEnabled) return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            if (tryParseProductPriceText(value) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppTheme.scaffoldBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppTheme.terracotta.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (option.key == 'market_pickup')
                        Text(
                          '(free pickup)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                    ],
                  ),
                  if (option.key == 'market_pickup') ...[
                    const SizedBox(height: 12),
                    Text(
                      'Which market should buyers collect from?',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _marketPickupNameController,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (!isEnabled || option.key != 'market_pickup') {
                          return null;
                        }
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter the market name';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        hintText: 'e.g. Bryanston Organic Market',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _marketPickupLocationController,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (!isEnabled || option.key != 'market_pickup') {
                          return null;
                        }
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter the market city or area';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        hintText: 'City / area, e.g. Johannesburg',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _marketPickupProvince,
                      decoration: const InputDecoration(
                        hintText: 'Market province',
                      ),
                      items: _saProvinces
                          .map(
                            (province) => DropdownMenuItem<String>(
                              value: province,
                              child: Text(province),
                            ),
                          )
                          .toList(),
                      validator: (value) {
                        if (!isEnabled || option.key != 'market_pickup') {
                          return null;
                        }
                        if (value == null || value.trim().isEmpty) {
                          return 'Select the market province';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() => _marketPickupProvince = value);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantCard(int index, _VariantDraft variant) {
    final totalImages = variant.imageUrls.length + variant.pendingFiles.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Combination ${index + 1}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_variants.length > 1)
                IconButton(
                  onPressed: () => _removeVariant(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: variant.optionOneController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: _optionOneNameController.text.trim().isEmpty
                  ? 'Option 1 Value'
                  : _optionOneNameController.text.trim(),
              hintText: 'e.g. Small, Large, Terracotta',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Add an option value';
              }
              return null;
            },
          ),
          if (_optionTwoNameController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: variant.optionTwoController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _optionTwoNameController.text.trim(),
                hintText: 'e.g. Red, Blue, Natural',
              ),
              validator: (value) {
                if (_optionTwoNameController.text.trim().isNotEmpty &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Add a second option value';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(_variantCurrentPriceLabel(variant)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: variant.priceController,
                      keyboardType: _priceKeyboard,
                      inputFormatters: _priceInputFormatters,
                      decoration: const InputDecoration(
                        hintText: 'What buyers pay',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return _requiredPriceValidator(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(salePriceFieldLabel),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: variant.compareAtPriceController,
                      keyboardType: _priceKeyboard,
                      inputFormatters: _priceInputFormatters,
                      validator: _optionalPriceValidator,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Optional discounted price',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: variant.stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Stock quantity'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              if (int.tryParse(value.trim()) == null) {
                return 'Invalid';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Text(
            '$totalImages/8 combination photos',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...variant.imageUrls.asMap().entries.map(
                  (entry) => _ImageTile(
                    key: ValueKey('variant-url-$index-${entry.key}'),
                    onRemove: () =>
                        setState(() => variant.imageUrls.removeAt(entry.key)),
                    onPreview: () => _showPhotoPreview(
                      image: CachedNetworkImageProvider(entry.value),
                      label: 'Combination ${index + 1} photo ${entry.key + 1}',
                    ),
                    child: CachedNetworkImage(
                      imageUrl: entry.value,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ),
                ),
                ...variant.pendingFiles.asMap().entries.map(
                  (entry) => _ImageTile(
                    key: ValueKey('variant-file-$index-${entry.key}'),
                    onRemove: () => setState(
                      () => variant.pendingFiles.removeAt(entry.key),
                    ),
                    onPreview: () => _showPhotoPreview(
                      image: FileImage(entry.value),
                      label:
                          'New combination ${index + 1} photo ${entry.key + 1}',
                    ),
                    isPending: true,
                    child: Image.file(entry.value, fit: BoxFit.cover),
                  ),
                ),
                if (totalImages < 8)
                  GestureDetector(
                    onTap: () => _showVariantImageSourcePicker(index),
                    child: Container(
                      width: 110,
                      height: 110,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.sand, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppTheme.baobab,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add Photos',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.baobab,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryDropdown() {
    if (_selectedCategoryId == null) return const SizedBox.shrink();
    final subcategoriesAsync = ref.watch(
      vendorSubcategoriesProvider(_selectedCategoryId!),
    );
    return subcategoriesAsync.when(
      data: (subs) {
        if (subs.isEmpty) {
          return Text(
            'No subcategories available',
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
          );
        }
        final validId = subs.any((s) => s.id == _selectedSubcategoryId)
            ? _selectedSubcategoryId
            : null;
        if (validId != _selectedSubcategoryId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedSubcategoryId = validId);
          });
        }
        return DropdownButtonFormField<String>(
          initialValue: validId,
          decoration: const InputDecoration(hintText: 'Select subcategory'),
          items: subs
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, style: GoogleFonts.poppins(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedSubcategoryId = v),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Could not load subcategories'),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

/// A product photo in display order. Pending photos carry a local [file]
/// until uploaded in place, so reordering and cover selection survive
/// the upload step. [id] is a stable key independent of list position.
class _ProductPhoto {
  _ProductPhoto.uploaded(this.url) : id = _nextId++, file = null;
  _ProductPhoto.pending(this.file) : id = _nextId++, url = null;

  static int _nextId = 0;
  final int id;
  String? url;
  File? file;

  bool get isPending => url == null;
}

class _ImageTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final VoidCallback? onPreview;
  final VoidCallback? onEdit;
  final bool isPending;
  final bool isCover;
  final int? index;

  const _ImageTile({
    super.key,
    required this.child,
    required this.onRemove,
    this.index,
    this.onPreview,
    this.onEdit,
    this.isPending = false,
    this.isCover = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 110,
      height: 110,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPreview,
                child: SizedBox.expand(child: child),
              ),
            ),
          ),
          if (isCover)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Cover',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (isPending)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'New',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (onEdit != null)
            Positioned(
              bottom: 5,
              right: 5,
              child: GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.crop_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (index == null) return content;
    return ReorderableDragStartListener(index: index!, child: content);
  }
}

class _VariantDraft {
  final String? id;
  final TextEditingController optionOneController;
  final TextEditingController optionTwoController;
  final TextEditingController priceController;
  final TextEditingController compareAtPriceController;
  final TextEditingController stockController;
  final List<String> imageUrls;
  final List<File> pendingFiles;

  _VariantDraft({
    this.id,
    required this.optionOneController,
    required this.optionTwoController,
    required this.priceController,
    required this.compareAtPriceController,
    required this.stockController,
    List<String>? imageUrls,
    List<File>? pendingFiles,
  }) : imageUrls = imageUrls ?? [],
       pendingFiles = pendingFiles ?? [];

  factory _VariantDraft.empty() {
    return _VariantDraft(
      optionOneController: TextEditingController(),
      optionTwoController: TextEditingController(),
      priceController: TextEditingController(),
      compareAtPriceController: TextEditingController(),
      stockController: TextEditingController(text: '0'),
    );
  }

  factory _VariantDraft.fromVariant(ProductVariant variant) {
    final pricingFields = pricingFieldsFromStoredValues(
      price: variant.price,
      compareAtPrice: variant.compareAtPrice,
    );
    return _VariantDraft(
      id: variant.id,
      optionOneController: TextEditingController(
        text: variant.optionValueAt(0) ?? variant.displayName,
      ),
      optionTwoController: TextEditingController(
        text: variant.optionValueAt(1) ?? '',
      ),
      priceController: TextEditingController(
        text: pricingFields.currentPriceText,
      ),
      compareAtPriceController: TextEditingController(
        text: pricingFields.salePriceText,
      ),
      stockController: TextEditingController(text: variant.stockQty.toString()),
      imageUrls: List<String>.from(variant.images),
    );
  }

  void dispose() {
    optionOneController.dispose();
    optionTwoController.dispose();
    priceController.dispose();
    compareAtPriceController.dispose();
    stockController.dispose();
  }
}
