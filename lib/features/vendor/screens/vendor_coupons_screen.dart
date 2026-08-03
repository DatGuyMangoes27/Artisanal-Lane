import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

class VendorCouponsScreen extends ConsumerWidget {
  const VendorCouponsScreen({super.key});

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final shop = await ref.read(vendorShopProvider.future);
    final products = await ref.read(vendorProductsProvider.future);
    if (!context.mounted || shop == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _CouponFormSheet(shop: shop, products: products),
    );
    ref.invalidate(vendorCouponsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(vendorCouponsProvider);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        title: Text(
          'Discount Codes',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        backgroundColor: AppTheme.terracotta,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('New code', style: GoogleFonts.poppins()),
      ),
      body: coupons.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.terracotta),
        ),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(vendorCouponsProvider),
          color: AppTheme.terracotta,
          child: items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(32),
                  children: [
                    const SizedBox(height: 100),
                    const Icon(
                      Icons.sell_outlined,
                      size: 58,
                      color: AppTheme.textHint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No discount codes yet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a code for your whole shop or selected products.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _CouponCard(coupon: items[index]),
                ),
        ),
      ),
    );
  }
}

class _CouponCard extends ConsumerWidget {
  final ShopCoupon coupon;

  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = coupon.discountType == 'percentage'
        ? '${coupon.discountValue.toStringAsFixed(coupon.discountValue % 1 == 0 ? 0 : 2)}% off'
        : 'R${coupon.discountValue.toStringAsFixed(2)} off';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  coupon.code,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.terracotta,
                  ),
                ),
              ),
              Switch.adaptive(
                value: coupon.isActive,
                activeTrackColor: AppTheme.terracotta,
                onChanged: (value) async {
                  await ref
                      .read(supabaseServiceProvider)
                      .setShopCouponActive(coupon.id, value);
                  ref.invalidate(vendorCouponsProvider);
                },
              ),
            ],
          ),
          Text(
            '$offer · ${coupon.scope == 'store' ? 'whole shop' : '${coupon.productIds.length} selected products'}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          if (coupon.description?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              coupon.description!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (coupon.minimumSubtotal > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Minimum product total R${coupon.minimumSubtotal.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await ref
                    .read(supabaseServiceProvider)
                    .deleteShopCoupon(coupon.id);
                ref.invalidate(vendorCouponsProvider);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponFormSheet extends ConsumerStatefulWidget {
  final Shop shop;
  final List<Product> products;

  const _CouponFormSheet({required this.shop, required this.products});

  @override
  ConsumerState<_CouponFormSheet> createState() => _CouponFormSheetState();
}

class _CouponFormSheetState extends ConsumerState<_CouponFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _value = TextEditingController();
  final _minimum = TextEditingController(text: '0');
  String _type = 'percentage';
  String _scope = 'store';
  final Set<String> _selectedProducts = {};
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _description.dispose();
    _value.dispose();
    _minimum.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scope == 'products' && _selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one product.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(supabaseServiceProvider)
          .createShopCoupon(
            shopId: widget.shop.id,
            code: _code.text,
            description: _description.text,
            discountType: _type,
            discountValue: double.parse(_value.text),
            scope: _scope,
            minimumSubtotal: double.tryParse(_minimum.text) ?? 0,
            productIds: _selectedProducts.toList(),
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create code: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create discount code',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Code (for example WELCOME10)',
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^[A-Za-z0-9_-]{3,32}$',
                      ).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Use 3-32 letters, numbers, hyphens or underscores.',
                ),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Discount type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'percentage',
                      child: Text('Percentage off'),
                    ),
                    DropdownMenuItem(
                      value: 'fixed',
                      child: Text('Fixed rand amount off'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _type = value!),
                ),
                TextFormField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Discount value',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount.';
                    }
                    if (_type == 'percentage' && amount > 100) {
                      return 'Percentage cannot exceed 100.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _minimum,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Minimum product total (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _scope,
                  decoration: const InputDecoration(labelText: 'Applies to'),
                  items: const [
                    DropdownMenuItem(
                      value: 'store',
                      child: Text('Everything in my shop'),
                    ),
                    DropdownMenuItem(
                      value: 'products',
                      child: Text('Selected products'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _scope = value!),
                ),
                if (_scope == 'products') ...[
                  const SizedBox(height: 16),
                  Text(
                    'Choose products',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  ...widget.products.map(
                    (product) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        product.title,
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      value: _selectedProducts.contains(product.id),
                      activeColor: AppTheme.terracotta,
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _selectedProducts.add(product.id);
                        } else {
                          _selectedProducts.remove(product.id);
                        }
                      }),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.terracotta,
                    ),
                    child: Text(_saving ? 'Creating...' : 'Create code'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
