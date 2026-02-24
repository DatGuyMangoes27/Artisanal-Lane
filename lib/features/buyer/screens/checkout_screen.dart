import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../providers/buyer_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedShipping = 'courier_guy';
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController(text: '');
  final _streetController = TextEditingController(text: '');
  final _cityController = TextEditingController(text: '');
  final _postalController = TextEditingController(text: '');
  final _provinceController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '');

  final _shippingOptions = [
    {
      'key': 'courier_guy',
      'name': 'The Courier Guy',
      'desc': 'Door-to-door delivery, 2-4 business days',
      'cost': 99.00,
      'icon': Icons.local_shipping_outlined,
    },
    {
      'key': 'pargo',
      'name': 'Pargo',
      'desc': 'Pick up at a Pargo point near you',
      'cost': 65.00,
      'icon': Icons.store_outlined,
    },
    {
      'key': 'paxi',
      'name': 'PAXI',
      'desc': 'Collect at PEP stores or PAXI points',
      'cost': 45.00,
      'icon': Icons.pin_drop_outlined,
    },
    {
      'key': 'market_pickup',
      'name': 'Market Pickup',
      'desc': 'Collect from the artisan in person',
      'cost': 0.00,
      'icon': Icons.handshake_outlined,
    },
  ];

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

  double get _selectedShippingCost {
    final option = _shippingOptions.firstWhere(
      (o) => o['key'] == _selectedShipping,
    );
    return option['cost'] as double;
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
          final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
          final shippingCost = _selectedShippingCost;
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
                    const SizedBox(height: 24),
                    ...List.generate(_shippingOptions.length, (index) {
                      final option = _shippingOptions[index];
                      final isSelected = _selectedShipping == option['key'];
                      return _buildShippingTile(option, isSelected);
                    }),

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

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.baobab,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Pay Now',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
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

  Widget _buildShippingTile(Map<String, Object> option, bool isSelected) {
    final cost = option['cost'] as double;
    final isFree = cost == 0;

    return GestureDetector(
      onTap: () => setState(() => _selectedShipping = option['key'] as String),
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
                option['icon'] as IconData,
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
                    option['name'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.terracotta : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option['desc'] as String,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              isFree ? 'FREE' : 'R${cost.toStringAsFixed(0)}',
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
