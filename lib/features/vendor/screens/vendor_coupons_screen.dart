import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
          const SizedBox(height: 6),
          Text(
            [
              if (coupon.startsAt != null)
                'Starts ${DateFormat('d MMM yyyy, HH:mm').format(coupon.startsAt!.toLocal())}',
              coupon.endsAt == null
                  ? 'No expiry'
                  : 'Ends ${DateFormat('d MMM yyyy, HH:mm').format(coupon.endsAt!.toLocal())}',
            ].join('  •  '),
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
          ),
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
  DateTime? _startsAt;
  DateTime? _endsAt;
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
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The end date must be after the start date.'),
        ),
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
            discountValue: double.parse(_value.text.replaceAll(',', '.')),
            scope: _scope,
            minimumSubtotal:
                double.tryParse(_minimum.text.replaceAll(',', '.')) ?? 0,
            startsAt: _startsAt,
            endsAt: _endsAt,
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

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startsAt : _endsAt;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: isStart ? 'SELECT START DATE' : 'SELECT END DATE',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? (isStart ? TimeOfDay.now() : const TimeOfDay(hour: 23, minute: 59))
          : TimeOfDay.fromDateTime(current),
      helpText: isStart ? 'SELECT START TIME' : 'SELECT END TIME',
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startsAt = selected;
        if (_endsAt != null && !_endsAt!.isAfter(selected)) _endsAt = null;
      } else {
        _endsAt = selected;
      }
    });
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    String? prefixText,
    String? suffixText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppTheme.sand.withValues(alpha: 0.75)),
    );
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 21, color: AppTheme.terracotta),
      prefixText: prefixText,
      suffixText: suffixText,
      filled: true,
      fillColor: AppTheme.bone.withValues(alpha: 0.72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.terracotta, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );
  }

  Widget _label(String text, {String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.terracotta,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField({required bool isStart}) {
    final value = isStart ? _startsAt : _endsAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(isStart ? 'Starts' : 'Ends', helper: 'Optional'),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _pickDateTime(isStart: isStart),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              decoration: BoxDecoration(
                color: AppTheme.bone.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.sand.withValues(alpha: 0.75),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 21,
                    color: AppTheme.terracotta,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value == null
                          ? 'No ${isStart ? 'start date' : 'expiry date'}'
                          : DateFormat('d MMM yyyy, HH:mm').format(value),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: value == null
                            ? AppTheme.textHint
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (value != null)
                    InkWell(
                      onTap: () => setState(() {
                        if (isStart) {
                          _startsAt = null;
                        } else {
                          _endsAt = null;
                        }
                      }),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(Icons.close_rounded, size: 18),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, size: 21),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: availableHeight * 0.92,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.sand,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.terracotta.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.sell_outlined,
                            color: AppTheme.terracotta,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create discount code',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Set the offer, products and schedule.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            'Code details',
                            'What customers enter at checkout.',
                          ),
                          _label(
                            'Discount code',
                            helper:
                                'Letters, numbers, hyphens and underscores.',
                          ),
                          TextFormField(
                            controller: _code,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _fieldDecoration(
                              hint: 'WELCOME10',
                              icon: Icons.confirmation_number_outlined,
                            ),
                            validator: (value) =>
                                RegExp(
                                  r'^[A-Za-z0-9_-]{3,32}$',
                                ).hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Use 3-32 valid characters.',
                          ),
                          const SizedBox(height: 16),
                          _label('Internal description', helper: 'Optional'),
                          TextFormField(
                            controller: _description,
                            decoration: _fieldDecoration(
                              hint: 'Launch promotion',
                              icon: Icons.notes_rounded,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _sectionTitle(
                            'Offer',
                            'Choose how much customers save.',
                          ),
                          _label('Discount type'),
                          DropdownButtonFormField<String>(
                            initialValue: _type,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            menuMaxHeight: 260,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            decoration: _fieldDecoration(
                              hint: 'Choose discount type',
                              icon: Icons.percent_rounded,
                            ),
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
                            onChanged: (value) =>
                                setState(() => _type = value!),
                          ),
                          const SizedBox(height: 16),
                          _label('Discount value'),
                          TextFormField(
                            controller: _value,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _fieldDecoration(
                              hint: _type == 'percentage' ? '10' : '50',
                              icon: Icons.price_change_outlined,
                              prefixText: _type == 'fixed' ? 'R ' : null,
                              suffixText: _type == 'percentage' ? '%' : null,
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                (value ?? '').replaceAll(',', '.'),
                              );
                              if (amount == null || amount <= 0) {
                                return 'Enter a valid amount.';
                              }
                              if (_type == 'percentage' && amount > 100) {
                                return 'Percentage cannot exceed 100.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _label(
                            'Minimum product total',
                            helper: 'Optional — excludes shipping and fees.',
                          ),
                          TextFormField(
                            controller: _minimum,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _fieldDecoration(
                              hint: '0',
                              icon: Icons.shopping_bag_outlined,
                              prefixText: 'R ',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                (value ?? '').replaceAll(',', '.'),
                              );
                              return amount == null || amount < 0
                                  ? 'Enter zero or a valid minimum.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 24),
                          _sectionTitle(
                            'Eligibility',
                            'Apply the code shop-wide or to chosen products.',
                          ),
                          _label('Applies to'),
                          DropdownButtonFormField<String>(
                            initialValue: _scope,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            menuMaxHeight: 260,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            decoration: _fieldDecoration(
                              hint: 'Choose products',
                              icon: Icons.inventory_2_outlined,
                            ),
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
                            onChanged: (value) =>
                                setState(() => _scope = value!),
                          ),
                          if (_scope == 'products') ...[
                            const SizedBox(height: 16),
                            _label(
                              'Choose products',
                              helper:
                                  '${_selectedProducts.length} selected of ${widget.products.length}',
                            ),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 280),
                              decoration: BoxDecoration(
                                color: AppTheme.scaffoldBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.sand.withValues(alpha: 0.7),
                                ),
                              ),
                              child: widget.products.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Text(
                                        'Add products before creating a product-specific code.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: widget.products.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(),
                                      itemBuilder: (_, index) {
                                        final product = widget.products[index];
                                        return CheckboxListTile(
                                          dense: true,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                          title: Text(
                                            product.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ),
                                          ),
                                          value: _selectedProducts.contains(
                                            product.id,
                                          ),
                                          activeColor: AppTheme.terracotta,
                                          onChanged: (selected) => setState(() {
                                            if (selected == true) {
                                              _selectedProducts.add(product.id);
                                            } else {
                                              _selectedProducts.remove(
                                                product.id,
                                              );
                                            }
                                          }),
                                        );
                                      },
                                    ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _sectionTitle(
                            'Schedule',
                            'Leave blank to start now and run indefinitely.',
                          ),
                          _dateField(isStart: true),
                          const SizedBox(height: 16),
                          _dateField(isStart: false),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.sand.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.terracotta,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(
                          _saving ? 'Creating code...' : 'Create discount code',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
