import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import '../utils/product_form_copy.dart';
import '../utils/vendor_payout_setup.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _compareAtPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _careController = TextEditingController();
  final _optionOneNameController = TextEditingController();
  final _optionTwoNameController = TextEditingController();
  final _optionOneValuesController = TextEditingController();
  final _optionTwoValuesController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  final Set<String> _selectedTags = {};
  bool _isPublished = true;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isUploading = false;

  final List<String> _imageUrls = [];
  final List<File> _pendingFiles = [];
  final List<_VariantDraft> _variants = [];
  List<ShippingOption> _shippingOptions = ShippingOption.defaults();
  final ImagePicker _picker = ImagePicker();
  late final Map<String, TextEditingController> _shippingPriceControllers = {
    for (final option in ShippingOption.defaults())
      option.key: TextEditingController(text: option.price.toStringAsFixed(2)),
  };

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadProduct();
    } else {
      _optionOneNameController.text = defaultProductOptionOneName;
      _optionTwoNameController.text = defaultProductOptionTwoName;
      _variants.add(_VariantDraft.empty());
      _seedShippingFromShopDefaults();
    }
  }

  Future<void> _seedShippingFromShopDefaults() async {
    try {
      final shop = await ref.read(vendorShopProvider.future);
      if (!mounted || shop == null || shop.shippingOptions.isEmpty) return;
      setState(() {
        _shippingOptions = shop.shippingOptions;
        for (final option in _shippingOptions) {
          _shippingPriceControllers[option.key]?.text = option.price.toStringAsFixed(2);
        }
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
            content: Text('Failed to load product: $e'),
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
    _careController.dispose();
    _optionOneNameController.dispose();
    _optionTwoNameController.dispose();
    _optionOneValuesController.dispose();
    _optionTwoValuesController.dispose();
    for (final controller in _shippingPriceControllers.values) {
      controller.dispose();
    }
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  void _initFromProduct(Product product) {
    if (_isInitialized) return;
    _isInitialized = true;
    _titleController.text = product.title;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toStringAsFixed(2);
    if (product.compareAtPrice != null) {
      _compareAtPriceController.text = product.compareAtPrice!.toStringAsFixed(
        2,
      );
    }
    _stockController.text = product.stockQty.toString();
    _selectedCategoryId = product.categoryId;
    _selectedSubcategoryId = product.subcategoryId;
    _selectedTags.addAll(product.tags);
    _isPublished = product.isPublished;
    _careController.text = product.careInstructions ?? '';
    _imageUrls.addAll(product.images);
    _shippingOptions = product.shippingOptions.isNotEmpty
        ? product.shippingOptions
        : ShippingOption.defaults();
    for (final option in _shippingOptions) {
      _shippingPriceControllers[option.key]?.text = option.price.toStringAsFixed(2);
    }
    final optionGroups = product.optionGroups;
    if (optionGroups.isNotEmpty) {
      _optionOneNameController.text = optionGroups.first.name;
      _optionOneValuesController.text = optionGroups.first.values.join(', ');
      if (optionGroups.length > 1) {
        _optionTwoNameController.text = optionGroups[1].name;
        _optionTwoValuesController.text = optionGroups[1].values.join(', ');
      }
    } else if (product.variants.isNotEmpty) {
      _optionOneNameController.text = defaultProductOptionTwoName;
    }
    if (product.variants.isNotEmpty) {
      _variants.addAll(product.variants.map(_VariantDraft.fromVariant));
    } else {
      _variants.add(_VariantDraft.fromLegacyProduct(product));
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
        setState(() => _pendingFiles.add(File(image.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() {
          _pendingFiles.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access gallery: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
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
          setState(() {
            _variants[index].pendingFiles.addAll(
              images.map((image) => File(image.path)),
            );
          });
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
        setState(() => _variants[index].pendingFiles.add(File(image.path)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add option photos: $error'),
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
      if (double.tryParse(variant.priceController.text.trim()) == null) {
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

  Future<List<String>> _uploadPendingImages() async {
    if (_pendingFiles.isEmpty) return [];
    final service = ref.read(supabaseServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return [];

    final uploaded = <String>[];
    for (final file in _pendingFiles) {
      final url = await service.uploadProductImage(userId, file);
      uploaded.add(url);
    }
    return uploaded;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final variantError = _validateVariants();
    if (variantError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(variantError, style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (_imageUrls.isEmpty &&
        _pendingFiles.isEmpty &&
        _variants.every(
          (variant) =>
              variant.imageUrls.isEmpty && variant.pendingFiles.isEmpty,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add at least one product photo',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final productShippingOptions = _buildProductShippingOptions();
    if (!productShippingOptions.any((option) => option.enabled)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enable at least one shipping option for this product.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_pendingFiles.isNotEmpty ||
          _variants.any((variant) => variant.pendingFiles.isNotEmpty)) {
        setState(() => _isUploading = true);
      }
      if (_pendingFiles.isNotEmpty) {
        final newUrls = await _uploadPendingImages();
        _imageUrls.addAll(newUrls);
        _pendingFiles.clear();
      }
      await _uploadVariantPendingImages();
      setState(() => _isUploading = false);

      final service = ref.read(supabaseServiceProvider);
      final shop = await ref.read(vendorShopProvider.future);
      if (shop == null) throw Exception('No shop found');

      final optionOneName = _optionOneNameController.text.trim();
      final optionTwoName = _optionTwoNameController.text.trim();

      final variantPayloads = _variants.asMap().entries.map((entry) {
        final variant = entry.value;
        final optionValues = <String>[
          variant.optionOneController.text.trim(),
          if (optionTwoName.isNotEmpty) variant.optionTwoController.text.trim(),
        ];
        final displayName = optionValues.join(' / ');
        return <String, dynamic>{
          if (variant.id != null) 'id': variant.id,
          'display_name': displayName,
          'color_name': optionValues.length == 1
              ? optionValues.first
              : displayName,
          'option_values': optionValues,
          'price': double.parse(variant.priceController.text.trim()),
          'compare_at_price':
              variant.compareAtPriceController.text.trim().isNotEmpty
              ? double.parse(variant.compareAtPriceController.text.trim())
              : null,
          'stock_qty': int.parse(variant.stockController.text.trim()),
          'images': List<String>.from(variant.imageUrls),
          'is_active': true,
          'sort_order': entry.key,
        };
      }).toList();

      final optionGroups = <Map<String, dynamic>>[
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

      final coverImages = _imageUrls.isNotEmpty
          ? _imageUrls
          : List<String>.from(variantPayloads.first['images'] as List);
      final fallbackPrice =
          (_priceController.text.trim().isNotEmpty
              ? double.tryParse(_priceController.text.trim())
              : null) ??
          (variantPayloads.first['price'] as double);
      final fallbackStock =
          (_stockController.text.trim().isNotEmpty
              ? int.tryParse(_stockController.text.trim())
              : null) ??
          _variants.fold<int>(
            0,
            (sum, variant) =>
                sum + int.parse(variant.stockController.text.trim()),
          );

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': fallbackPrice,
        'stock_qty': fallbackStock,
        'is_published': _isPublished,
        'images': coverImages,
        'option_groups': optionGroups,
        'tags': _selectedTags.toList(),
        'shipping_options': productShippingOptions
            .map((option) => option.toJson())
            .toList(),
        'variants': variantPayloads,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
        'subcategory_id': _selectedSubcategoryId,
        if (_compareAtPriceController.text.isNotEmpty)
          'compare_at_price': double.parse(_compareAtPriceController.text),
        if (_careController.text.trim().isNotEmpty)
          'care_instructions': _careController.text.trim(),
      };

      if (_isEditing) {
        await service.updateProduct(widget.productId!, data);
      } else {
        await service.createProduct(shop.id, data);
      }

      ref.invalidate(vendorProductsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
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

  void _removeUploadedImage(int index) {
    setState(() => _imageUrls.removeAt(index));
  }

  void _removePendingImage(int index) {
    setState(() => _pendingFiles.removeAt(index));
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

    final totalImages = _imageUrls.length + _pendingFiles.length;

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

    if (!_isEditing && !payoutReady) {
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

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Product' : 'New Product',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Photos section ──────────────────────────────────
            _buildLabel('Fallback Photos'),
            const SizedBox(height: 4),
            Text(
              '$totalImages/8 photos added · used when no option photos are set',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Uploaded images (from server)
                  ..._imageUrls.asMap().entries.map(
                    (entry) => _ImageTile(
                      key: ValueKey('url-${entry.key}'),
                      onRemove: () => _removeUploadedImage(entry.key),
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
                  // Pending local files
                  ..._pendingFiles.asMap().entries.map(
                    (entry) => _ImageTile(
                      key: ValueKey('file-${entry.key}'),
                      onRemove: () => _removePendingImage(entry.key),
                      isPending: true,
                      child: Image.file(entry.value, fit: BoxFit.cover),
                    ),
                  ),
                  // Add button
                  if (totalImages < 8)
                    GestureDetector(
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
                    ),
                ],
              ),
            ),
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
              decoration: const InputDecoration(
                hintText: 'Describe your product...',
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('Category'),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(hintText: 'Select category'),
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
                      labelText: _optionOneNameController.text.trim().isEmpty
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
                      labelText: _optionTwoNameController.text.trim().isEmpty
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
                icon: const Icon(Icons.add_rounded, color: AppTheme.terracotta),
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
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (_variants.isNotEmpty) return null;
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                        decoration: const InputDecoration(
                          hintText: 'Optional when variants are set',
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
                        keyboardType: TextInputType.number,
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

            _buildLabel('Fallback Stock Quantity'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (_variants.isNotEmpty) return null;
                if (v == null || v.isEmpty) return 'Required';
                if (int.tryParse(v) == null) return 'Invalid';
                return null;
              },
              decoration: const InputDecoration(
                hintText: 'Optional when variants are set',
              ),
            ),
            const SizedBox(height: 20),

            _buildProductShippingSection(),
            const SizedBox(height: 20),

            // ── Care Instructions ────────────────────────────────
            _buildCareSection(),
            const SizedBox(height: 20),

            SwitchListTile(
              value: _isPublished,
              onChanged: (v) => setState(() => _isPublished = v),
              title: Text(
                'Publish',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _isPublished ? 'Visible to buyers' : 'Saved as draft',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textHint,
                ),
              ),
              activeTrackColor: AppTheme.baobab,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),

            GradientButton(
              label: _isEditing ? 'Save Changes' : 'Create Product',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _save,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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

  List<ShippingOption> _buildProductShippingOptions() {
    return _shippingOptions.map((option) {
      final rawPrice = _shippingPriceControllers[option.key]?.text.trim() ?? '';
      final parsedPrice = double.tryParse(rawPrice);
      return option.copyWith(price: parsedPrice ?? option.price);
    }).toList(growable: false);
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
        ..._shippingOptions.map(_buildProductShippingOptionCard),
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
              child: Row(
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                        if (double.tryParse(value.trim()) == null) {
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
                            color: AppTheme.terracotta.withValues(alpha: 0.5),
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
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'What buyers pay'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value.trim()) == null) {
                          return 'Invalid';
                        }
                        return null;
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
                      keyboardType: TextInputType.number,
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

class _ImageTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  final bool isPending;

  const _ImageTile({
    super.key,
    required this.child,
    required this.onRemove,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.expand(child: child),
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
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
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
        ],
      ),
    );
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
    return _VariantDraft(
      id: variant.id,
      optionOneController: TextEditingController(
        text: variant.optionValueAt(0) ?? variant.displayName,
      ),
      optionTwoController: TextEditingController(
        text: variant.optionValueAt(1) ?? '',
      ),
      priceController: TextEditingController(
        text: variant.price.toStringAsFixed(2),
      ),
      compareAtPriceController: TextEditingController(
        text: variant.compareAtPrice?.toStringAsFixed(2) ?? '',
      ),
      stockController: TextEditingController(text: variant.stockQty.toString()),
      imageUrls: List<String>.from(variant.images),
    );
  }

  factory _VariantDraft.fromLegacyProduct(Product product) {
    return _VariantDraft(
      optionOneController: TextEditingController(),
      optionTwoController: TextEditingController(),
      priceController: TextEditingController(
        text: product.price.toStringAsFixed(2),
      ),
      compareAtPriceController: TextEditingController(
        text: product.compareAtPrice?.toStringAsFixed(2) ?? '',
      ),
      stockController: TextEditingController(text: product.stockQty.toString()),
      imageUrls: List<String>.from(product.images),
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
