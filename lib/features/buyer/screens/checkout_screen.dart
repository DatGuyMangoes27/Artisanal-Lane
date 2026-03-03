import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../models/shipping_option.dart';
import '../../../widgets/gradient_button.dart';
import '../providers/buyer_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _selectedShipping;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController(text: '');
  final _streetController = TextEditingController(text: '');
  final _cityController = TextEditingController(text: '');
  final _postalController = TextEditingController(text: '');
  final _provinceController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '');

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _provinceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  double _selectedShippingCost(List<ShippingOption> options) {
    if (_selectedShipping == null) return 0;
    final match = options.where((o) => o.key == _selectedShipping).toList();
    return match.isNotEmpty ? match.first.price : 0;
  }

  void _initSelection(List<ShippingOption> options) {
    if (_selectedShipping == null && options.isNotEmpty) {
      final enabled = options.where((o) => o.enabled).toList();
      if (enabled.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedShipping = enabled.first.key);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartItemsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Checkout',
          style: GoogleFonts.playfairDisplay(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: cartAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('Your cart is empty', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
            );
          }

          // Derive shop ID from cart items
          final shopId = items
              .map((i) => i.product?.shopId)
              .whereType<String>()
              .toSet()
              .firstOrNull;

          final shippingAsync = shopId != null
              ? ref.watch(shopShippingOptionsProvider(shopId))
              : const AsyncData(<ShippingOption>[]);

          return shippingAsync.when(
            data: (shippingOptions) {
              final enabledOptions = shippingOptions.where((o) => o.enabled).toList();
              _initSelection(enabledOptions);

              final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
              final shippingCost = _selectedShippingCost(enabledOptions);
              final total = subtotal + shippingCost;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Shipping Address'),
                    const SizedBox(height: 24),

                    _buildTextField(label: 'Full Name', controller: _nameController),
                    const SizedBox(height: 16),
                    _buildTextField(label: 'Street Address', controller: _streetController),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(label: 'City', controller: _cityController)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Postal Code',
                            controller: _postalController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(label: 'Province', controller: _provinceController),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Phone Number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),

                    const SizedBox(height: 32),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Shipping Method'),
                    const SizedBox(height: 8),
                    if (enabledOptions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'This shop has not configured shipping options yet.',
                          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 16),
                      ...enabledOptions.map((opt) => _buildShippingTile(opt)),
                    ],

                    const SizedBox(height: 32),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Order Summary'),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Subtotal (${items.length} items)', 'R${subtotal.toStringAsFixed(0)}'),
                          const SizedBox(height: 12),
                          _summaryRow(
                            'Shipping',
                            shippingCost == 0 ? 'FREE' : 'R${shippingCost.toStringAsFixed(0)}',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: AppTheme.sand.withValues(alpha: 0.3), height: 1),
                          ),
                          _summaryRow('Total', 'R${total.toStringAsFixed(0)}', isTotal: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    GradientButton(
                      label: 'Pay Now',
                      onPressed: enabledOptions.isEmpty || _selectedShipping == null
                          ? null
                          : () {
                              if (!_formKey.currentState!.validate()) return;
                              final checkoutData = {
                                'items': items,
                                'subtotal': subtotal,
                                'shippingCost': shippingCost,
                                'shippingMethod': _selectedShipping,
                                'total': total,
                                'address': {
                                  'name': _nameController.text,
                                  'street': _streetController.text,
                                  'city': _cityController.text,
                                  'postal_code': _postalController.text,
                                  'province': _provinceController.text,
                                  'phone': _phoneController.text,
                                },
                              };
                              context.push('/cart/payment', extra: checkoutData);
                            },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2)),
            error: (_, __) => Center(child: Text('Could not load shipping options', style: GoogleFonts.poppins(color: AppTheme.textSecondary))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2)),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
      style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 14),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppTheme.textHint, size: 20) : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.sand.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.terracotta, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildShippingTile(ShippingOption option) {
    final isSelected = _selectedShipping == option.key;
    final isFree = option.price == 0;

    return GestureDetector(
      onTap: () => setState(() => _selectedShipping = option.key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isSelected ? AppTheme.terracotta : AppTheme.sand.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.terracotta.withValues(alpha: 0.05) : AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                option.icon,
                color: isSelected ? AppTheme.terracotta : AppTheme.textHint,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.terracotta : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              isFree ? 'FREE' : 'R${option.price.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isFree ? AppTheme.baobab : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
            color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: isTotal
              ? GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.sienna)
              : GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}
