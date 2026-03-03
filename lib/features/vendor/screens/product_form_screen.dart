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

  String? _selectedCategoryId;
  bool _isPublished = true;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isUploading = false;

  final List<String> _imageUrls = [];
  final List<File> _pendingFiles = [];
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadProduct();
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
          SnackBar(content: Text('Failed to load product: $e'), backgroundColor: AppTheme.error),
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
    super.dispose();
  }

  void _initFromProduct(Product product) {
    if (_isInitialized) return;
    _isInitialized = true;
    _titleController.text = product.title;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toStringAsFixed(2);
    if (product.compareAtPrice != null) {
      _compareAtPriceController.text = product.compareAtPrice!.toStringAsFixed(2);
    }
    _stockController.text = product.stockQty.toString();
    _selectedCategoryId = product.categoryId;
    _isPublished = product.isPublished;
    _careController.text = product.careInstructions ?? '';
    _imageUrls.addAll(product.images);
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
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.terracotta),
                ),
                title: Text('Take Photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text('Use your camera', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
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
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.baobab),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text('Pick from your photos', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
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
          SnackBar(content: Text('Could not access camera: $e'), backgroundColor: AppTheme.error),
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
          SnackBar(content: Text('Could not access gallery: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
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
    if (_imageUrls.isEmpty && _pendingFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one product photo', style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_pendingFiles.isNotEmpty) {
        setState(() => _isUploading = true);
        final newUrls = await _uploadPendingImages();
        _imageUrls.addAll(newUrls);
        _pendingFiles.clear();
        setState(() => _isUploading = false);
      }

      final service = ref.read(supabaseServiceProvider);
      final shop = await ref.read(vendorShopProvider.future);
      if (shop == null) throw Exception('No shop found');

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'stock_qty': int.parse(_stockController.text),
        'is_published': _isPublished,
        'images': _imageUrls,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(vendorCategoriesProvider);

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
          title: Text('Edit Product', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2)),
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
            _buildLabel('Photos'),
            const SizedBox(height: 4),
            Text(
              '$totalImages/8 photos added',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Uploaded images (from server)
                  ..._imageUrls.asMap().entries.map((entry) => _ImageTile(
                        key: ValueKey('url-${entry.key}'),
                        onRemove: () => _removeUploadedImage(entry.key),
                        child: CachedNetworkImage(
                          imageUrl: entry.value,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: AppTheme.textHint),
                        ),
                      )),
                  // Pending local files
                  ..._pendingFiles.asMap().entries.map((entry) => _ImageTile(
                        key: ValueKey('file-${entry.key}'),
                        onRemove: () => _removePendingImage(entry.key),
                        isPending: true,
                        child: Image.file(entry.value, fit: BoxFit.cover),
                      )),
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
                              child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.baobab, size: 20),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.baobab),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Uploading photos...',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.baobab),
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
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              decoration: const InputDecoration(hintText: 'Handwoven Basket'),
            ),
            const SizedBox(height: 20),

            _buildLabel('Description'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Describe your product...'),
            ),
            const SizedBox(height: 20),

            _buildLabel('Category'),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(hintText: 'Select category'),
                items: categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, style: GoogleFonts.poppins(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load categories'),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Price (R)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                        decoration: const InputDecoration(hintText: '0.00'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Compare at (R)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _compareAtPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Optional'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildLabel('Stock Quantity'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (int.tryParse(v) == null) return 'Invalid';
                return null;
              },
              decoration: const InputDecoration(hintText: '0'),
            ),
            const SizedBox(height: 20),

            // ── Care Instructions ────────────────────────────────
            _buildCareSection(),
            const SizedBox(height: 20),

            SwitchListTile(
              value: _isPublished,
              onChanged: (v) => setState(() => _isPublished = v),
              title: Text('Publish', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                _isPublished ? 'Visible to buyers' : 'Saved as draft',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
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
            child: const Icon(Icons.spa_outlined, color: Colors.white, size: 18),
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
                hintStyle:
                    GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                hintMaxLines: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
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
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
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
