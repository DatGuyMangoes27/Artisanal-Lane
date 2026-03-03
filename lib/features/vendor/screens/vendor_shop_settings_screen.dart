import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme.dart';
import '../../../models/shipping_option.dart';
import '../../../widgets/gradient_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorShopSettingsScreen extends ConsumerStatefulWidget {
  const VendorShopSettingsScreen({super.key});

  @override
  ConsumerState<VendorShopSettingsScreen> createState() =>
      _VendorShopSettingsScreenState();
}

class _VendorShopSettingsScreenState
    extends ConsumerState<VendorShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _brandStoryController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();

  String? _logoUrl;
  String? _coverUrl;
  File? _pendingLogo;
  File? _pendingCover;
  bool _isLoading = false;
  bool _isInitialized = false;
  List<ShippingOption> _shippingOptions = ShippingOption.defaults();
  // Controllers for per-method price inputs
  late final Map<String, TextEditingController> _priceControllers = {
    for (final o in ShippingOption.defaults())
      o.key: TextEditingController(text: o.price.toStringAsFixed(2))
  };

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _brandStoryController.dispose();
    _locationController.dispose();
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage({required bool isLogo}) async {
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
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.sand, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(
                isLogo ? 'Shop Logo' : 'Cover Image',
                style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppTheme.terracotta.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.terracotta),
                ),
                title: Text('Take Photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text('Use your camera', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
                onTap: () {
                  Navigator.pop(ctx);
                  _doPick(ImageSource.camera, isLogo: isLogo);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppTheme.baobab.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.baobab),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                subtitle: Text('Pick from your photos', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint)),
                onTap: () {
                  Navigator.pop(ctx);
                  _doPick(ImageSource.gallery, isLogo: isLogo);
                },
              ),
              if ((isLogo ? (_logoUrl ?? _pendingLogo) : (_coverUrl ?? _pendingCover)) != null)
                ListTile(
                  leading: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_outline, color: AppTheme.error),
                  ),
                  title: Text('Remove', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppTheme.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      if (isLogo) {
                        _logoUrl = null;
                        _pendingLogo = null;
                      } else {
                        _coverUrl = null;
                        _pendingCover = null;
                      }
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doPick(ImageSource source, {required bool isLogo}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: isLogo ? 512 : 1400,
        maxHeight: isLogo ? 512 : 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          if (isLogo) {
            _pendingLogo = File(image.path);
          } else {
            _pendingCover = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      final shop = await ref.read(vendorShopProvider.future);
      if (shop == null) throw Exception('No shop found');
      final userId = ref.read(currentUserIdProvider);

      if (userId != null) {
        if (_pendingLogo != null) {
          _logoUrl = await service.uploadShopImage(userId, _pendingLogo!, folder: 'logo');
          _pendingLogo = null;
        }
        if (_pendingCover != null) {
          _coverUrl = await service.uploadShopImage(userId, _pendingCover!, folder: 'cover');
          _pendingCover = null;
        }
      }

      // Collect current price values from controllers
      final updatedShipping = _shippingOptions.map((opt) {
        final price = double.tryParse(
                _priceControllers[opt.key]?.text ?? '') ??
            opt.price;
        return opt.copyWith(price: price);
      }).toList();

      await service.updateShop(shop.id, {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'brand_story': _brandStoryController.text.trim(),
        'logo_url': _logoUrl,
        'cover_image_url': _coverUrl,
        'location': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        'shipping_options':
            updatedShipping.map((o) => o.toJson()).toList(),
      });

      ref.invalidate(vendorShopProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shop updated', style: GoogleFonts.poppins()), backgroundColor: AppTheme.baobab),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(vendorShopProvider);

    shopAsync.whenData((shop) {
      if (!_isInitialized && shop != null) {
        _isInitialized = true;
        _nameController.text = shop.name;
        _bioController.text = shop.bio ?? '';
        _brandStoryController.text = shop.brandStory ?? '';
        _locationController.text = shop.location ?? '';
        _logoUrl = shop.logoUrl;
        _coverUrl = shop.coverImageUrl;
        _shippingOptions = shop.shippingOptions.isNotEmpty
            ? shop.shippingOptions
            : ShippingOption.defaults();
        for (final opt in _shippingOptions) {
          _priceControllers[opt.key]?.text = opt.price.toStringAsFixed(2);
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text('Shop Settings', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
      ),
      body: shopAsync.when(
        data: (_) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ── Cover image ────────────────────────────────────
              _buildLabel('Cover Image'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _pickImage(isLogo: false),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.sand, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildCoverPreview(),
                ),
              ),
              const SizedBox(height: 24),

              // ── Logo ───────────────────────────────────────────
              _buildLabel('Shop Logo'),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickImage(isLogo: true),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.sand, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildLogoPreview(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tap to change',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Square image works best',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Text fields ────────────────────────────────────
              _buildLabel('Shop Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                decoration: const InputDecoration(hintText: 'Your shop name'),
              ),
              const SizedBox(height: 20),

              _buildLabel('Bio'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Short description of your shop'),
              ),
              const SizedBox(height: 20),

              _buildLabel('Brand Story'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _brandStoryController,
                maxLines: 5,
                decoration: const InputDecoration(hintText: 'Tell your story...'),
              ),
              const SizedBox(height: 20),

              _buildLabel('Location'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(hintText: 'e.g. Cape Town, South Africa'),
              ),
              const SizedBox(height: 36),

              // ── Shipping & Delivery ────────────────────────────
              _buildLabel('Shipping & Delivery'),
              const SizedBox(height: 4),
              Text(
                'Choose which methods you offer and set your own price for each.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
              ),
              const SizedBox(height: 12),
              ..._shippingOptions.map((opt) => _buildShippingOptionCard(opt)),
              const SizedBox(height: 36),

              GradientButton(
                label: 'Save Changes',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _save,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildCoverPreview() {
    if (_pendingCover != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_pendingCover!, fit: BoxFit.cover),
          _imageOverlayBadge('New'),
          _editIcon(),
        ],
      );
    }
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(imageUrl: _coverUrl!, fit: BoxFit.cover),
          _editIcon(),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: AppTheme.baobab.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.baobab, size: 24),
        ),
        const SizedBox(height: 8),
        Text('Tap to add cover image', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.baobab, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLogoPreview() {
    if (_pendingLogo != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_pendingLogo!, fit: BoxFit.cover),
          _imageOverlayBadge('New'),
        ],
      );
    }
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      return CachedNetworkImage(imageUrl: _logoUrl!, fit: BoxFit.cover);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppTheme.terracotta.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.terracotta, size: 18),
        ),
        const SizedBox(height: 4),
        Text('Logo', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.terracotta, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _editIcon() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        width: 32, height: 32,
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.edit, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _imageOverlayBadge(String text) {
    return Positioned(
      bottom: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildShippingOptionCard(ShippingOption opt) {
    final isEnabled = opt.enabled;
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
          // Header row: icon, name/desc, toggle
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
                  child: Icon(opt.icon,
                      size: 20,
                      color: isEnabled
                          ? AppTheme.terracotta
                          : AppTheme.textHint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? AppTheme.textPrimary
                              : AppTheme.textHint,
                        ),
                      ),
                      Text(
                        opt.description,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (val) {
                    setState(() {
                      _shippingOptions = _shippingOptions
                          .map((o) =>
                              o.key == opt.key ? o.copyWith(enabled: val) : o)
                          .toList();
                    });
                  },
                  activeColor: AppTheme.terracotta,
                  activeTrackColor: AppTheme.terracotta.withValues(alpha: 0.2),
                  inactiveThumbColor: AppTheme.textHint,
                  inactiveTrackColor: AppTheme.bone,
                ),
              ],
            ),
          ),

          // Price row (only when enabled)
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
                        color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text('R',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _priceControllers[opt.key],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: AppTheme.scaffoldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color:
                                  AppTheme.terracotta.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (opt.key == 'market_pickup')
                    Text(
                      '(free pickup)',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textHint),
                    ),
                ],
              ),
            ),
          ],
        ],
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
