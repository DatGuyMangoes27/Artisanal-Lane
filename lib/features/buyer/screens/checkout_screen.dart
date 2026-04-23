import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../core/pricing/pricing.dart';
import '../../../models/cart_item.dart';
import '../../../models/courier_guy_locker.dart';
import '../../../models/shipping_option.dart';
import '../../../widgets/gradient_button.dart';
import '../providers/buyer_providers.dart';
import '../utils/checkout_validation.dart';
import '../utils/product_shipping_checkout.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
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

  String? _selectedShipping;
  String? _selectedProvince;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _fullNameFieldKey = GlobalKey();
  final _streetFieldKey = GlobalKey();
  final _cityFieldKey = GlobalKey();
  final _postalFieldKey = GlobalKey();
  final _provinceFieldKey = GlobalKey();
  final _phoneFieldKey = GlobalKey();
  final _shippingSectionKey = GlobalKey();
  final _pickupPointFieldKey = GlobalKey();
  final _nameFocusNode = FocusNode();
  final _streetFocusNode = FocusNode();
  final _cityFocusNode = FocusNode();
  final _postalFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _pickupPointFocusNode = FocusNode();

  final _nameController = TextEditingController(text: '');
  final _streetController = TextEditingController(text: '');
  final _cityController = TextEditingController(text: '');
  final _postalController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '');
  final _pickupPointController = TextEditingController(text: '');
  final _courierGuySearchController = TextEditingController(text: '');
  bool _submitAttempted = false;
  bool _isSubmittingPayment = false;
  String? _courierGuyLockerProvince;
  bool _isLoadingCourierGuyLockers = false;
  String? _courierGuyLockerError;
  CourierGuyLocker? _selectedCourierGuyLocker;
  List<CourierGuyLocker> _courierGuyLockers = const [];
  Timer? _courierGuySearchDebounce;

  @override
  void dispose() {
    _scrollController.dispose();
    _nameFocusNode.dispose();
    _streetFocusNode.dispose();
    _cityFocusNode.dispose();
    _postalFocusNode.dispose();
    _phoneFocusNode.dispose();
    _pickupPointFocusNode.dispose();
    _courierGuySearchDebounce?.cancel();
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _phoneController.dispose();
    _pickupPointController.dispose();
    _courierGuySearchController.dispose();
    super.dispose();
  }

  double _selectedShippingCost({
    required List<CartItem> items,
    required List<List<ShippingOption>> productShippingOptions,
  }) {
    if (_selectedShipping == null) return 0;
    return calculateProductShippingTotal(
      methodKey: _selectedShipping!,
      itemQuantities: items.map((item) => item.quantity).toList(growable: false),
      productShippingOptions: productShippingOptions,
    );
  }

  void _initSelection(List<ShippingOption> options) {
    final validSelection =
        _selectedShipping != null &&
        options.any((option) => option.key == _selectedShipping);
    if (validSelection) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedShipping = options.isNotEmpty ? options.first.key : null);
    });
  }

  String _shippingUnavailableMessage(int itemCount) {
    if (itemCount <= 1) {
      return 'This product does not have any shipping options available yet.';
    }
    return 'The products in this basket do not share an available shipping option yet.';
  }

  bool _requiresPickupPoint(String? shippingMethod) {
    return shippingMethod == 'courier_guy' ||
        shippingMethod == 'pargo';
  }

  bool _isMarketPickup(String? shippingMethod) {
    return shippingMethod == 'market_pickup';
  }

  String _pickupPointLabel(String? shippingMethod) {
    switch (shippingMethod) {
      case 'courier_guy':
        return 'Courier Guy locker / branch / drop-off point';
      case 'pargo':
        return 'Pargo pickup point';
      default:
        return 'Pickup point';
    }
  }

  String _pickupPointHint(String? shippingMethod) {
    switch (shippingMethod) {
      case 'courier_guy':
        return 'Enter the locker, branch, or drop-off location the seller should use';
      case 'pargo':
        return 'Enter the Pargo point name, code, or branch the seller should use';
      default:
        return 'Enter the pickup point details';
    }
  }

  String _courierGuyLockerSummary(CourierGuyLocker locker) {
    return [
      locker.title,
      if (locker.address.isNotEmpty) locker.address,
      if (locker.province.isNotEmpty) locker.province,
    ].join(' • ');
  }

  void _clearCourierGuyLockerSelection() {
    _selectedCourierGuyLocker = null;
    _pickupPointController.clear();
  }

  Future<void> _searchCourierGuyLockers() async {
    final search = _courierGuySearchController.text.trim();
    final province = _courierGuyLockerProvince?.trim();
    if (search.length < 2 && (province == null || province.isEmpty)) {
      if (!mounted) return;
      setState(() {
        _courierGuyLockers = const [];
        _courierGuyLockerError = null;
        _isLoadingCourierGuyLockers = false;
      });
      return;
    }

    setState(() {
      _isLoadingCourierGuyLockers = true;
      _courierGuyLockerError = null;
    });

    try {
      final lockers = await ref.read(supabaseServiceProvider).searchCourierGuyLockers(
            query: search,
            province: province,
          );
      if (!mounted) return;
      setState(() {
        _courierGuyLockers = lockers;
        _isLoadingCourierGuyLockers = false;
      });
    } catch (error, stackTrace) {
      print(
        '[locker-debug] checkout screen search failed query="$search" province="$province" error=$error stackTrace=$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _courierGuyLockers = const [];
        _courierGuyLockerError =
            'Could not load Courier Guy lockers right now. Try again in a moment.';
        _isLoadingCourierGuyLockers = false;
      });
    }
  }

  void _scheduleCourierGuyLockerSearch() {
    _courierGuySearchDebounce?.cancel();
    _courierGuySearchDebounce = Timer(
      const Duration(milliseconds: 300),
      _searchCourierGuyLockers,
    );
  }

  void _selectCourierGuyLocker(CourierGuyLocker locker) {
    setState(() {
      _selectedCourierGuyLocker = locker;
      _pickupPointController.text = _courierGuyLockerSummary(locker);
      _courierGuyLockers = const [];
      _courierGuyLockerError = null;
    });
  }

  CheckoutFormSnapshot _checkoutSnapshot(List<ShippingOption> enabledOptions) {
    return CheckoutFormSnapshot(
      fullName: _nameController.text,
      streetAddress: _streetController.text,
      city: _cityController.text,
      postalCode: _postalController.text,
      province: _selectedProvince,
      phoneNumber: _phoneController.text,
      selectedShippingMethod: _selectedShipping,
      hasAvailableShippingMethods: enabledOptions.isNotEmpty,
      requiresPickupPoint: _requiresPickupPoint(_selectedShipping),
      pickupPoint: _pickupPointController.text,
    );
  }

  Future<void> _ensureFieldVisible(CheckoutField field) async {
    final context = switch (field) {
      CheckoutField.fullName => _fullNameFieldKey.currentContext,
      CheckoutField.streetAddress => _streetFieldKey.currentContext,
      CheckoutField.city => _cityFieldKey.currentContext,
      CheckoutField.postalCode => _postalFieldKey.currentContext,
      CheckoutField.province => _provinceFieldKey.currentContext,
      CheckoutField.phoneNumber => _phoneFieldKey.currentContext,
      CheckoutField.shippingMethod => _shippingSectionKey.currentContext,
      CheckoutField.pickupPoint => _pickupPointFieldKey.currentContext,
    };

    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    } else if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    if (!mounted) return;

    switch (field) {
      case CheckoutField.fullName:
        _nameFocusNode.requestFocus();
        break;
      case CheckoutField.streetAddress:
        _streetFocusNode.requestFocus();
        break;
      case CheckoutField.city:
        _cityFocusNode.requestFocus();
        break;
      case CheckoutField.postalCode:
        _postalFocusNode.requestFocus();
        break;
      case CheckoutField.phoneNumber:
        _phoneFocusNode.requestFocus();
        break;
      case CheckoutField.pickupPoint:
        _pickupPointFocusNode.requestFocus();
        break;
      case CheckoutField.province:
      case CheckoutField.shippingMethod:
        FocusScope.of(this.context).unfocus();
        break;
    }
  }

  Future<void> _showBlockingFeedback(CheckoutField field) async {
    if (mounted) {
      setState(() => _submitAttempted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            checkoutBlockingMessage(field),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _ensureFieldVisible(field);
  }

  Future<void> _submitCheckout({
    required List<dynamic> items,
    required double subtotal,
    required double giftFee,
    required double shippingCost,
    required double total,
    required List<ShippingOption> enabledOptions,
  }) async {
    if (_isSubmittingPayment) return;

    final incompleteField = firstIncompleteCheckoutField(
      _checkoutSnapshot(enabledOptions),
    );
    if (incompleteField != null) {
      await _showBlockingFeedback(incompleteField);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _submitAttempted = true);
      return;
    }

    setState(() {
      _submitAttempted = true;
      _isSubmittingPayment = true;
    });

    final checkoutData = {
      'items': items,
      'subtotal': subtotal,
      'giftFee': giftFee,
      'shippingCost': shippingCost,
      'shippingMethod': _selectedShipping,
      'total': total,
      'address': {
        'name': _nameController.text,
        'street': _streetController.text,
        'city': _cityController.text,
        'postal_code': _postalController.text,
        'province': _selectedProvince,
        'country': 'South Africa',
        'phone': _phoneController.text,
        if (_selectedShipping == 'courier_guy' && _selectedCourierGuyLocker != null)
          'pickup_point': _selectedCourierGuyLocker!.toOrderJson()
        else if (_pickupPointController.text.trim().isNotEmpty)
          'pickup_point': _pickupPointController.text.trim(),
      },
    };

    try {
      await context.push('/cart/payment', extra: checkoutData);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartItemsProvider);
    final giftOptions = ref.watch(giftOptionsProvider);
    final isGift = giftOptions.isGift;
    final addressTitle = isGift
        ? 'Recipient Delivery Details'
        : 'Shipping Address';
    final nameLabel = isGift ? 'Recipient Full Name' : 'Full Name';
    final phoneLabel = isGift ? 'Recipient Phone Number' : 'Phone Number';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
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
              child: Text(
                'Your cart is empty',
                style: GoogleFonts.poppins(color: AppTheme.textSecondary),
              ),
            );
          }

          final productShippingOptions = items
              .map((item) => item.product?.shippingOptions ?? const <ShippingOption>[])
              .toList(growable: false);
          final enabledOptions =
              availableShippingOptionsForProducts(productShippingOptions);
          _initSelection(enabledOptions);

          final subtotal = items.fold<double>(
            0,
            (sum, item) => sum + item.lineTotal,
          );
          final giftFee = giftFeeForSelection(isGift: isGift);
          final shippingCost = _selectedShippingCost(
            items: items,
            productShippingOptions: productShippingOptions,
          );
          final total = calculateCheckoutTotal(
            subtotal: subtotal,
            shippingCost: shippingCost,
            isGift: isGift,
          );

          return SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: _submitAttempted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        _buildSectionTitle(addressTitle),
                        const SizedBox(height: 12),
                        _buildInfoNote(
                          'Orders can be placed from abroad, but delivery addresses must be within South Africa.',
                        ),
                        const SizedBox(height: 24),

                        _buildTextField(
                          key: _fullNameFieldKey,
                          label: nameLabel,
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          key: _streetFieldKey,
                          label: 'Street Address',
                          controller: _streetController,
                          focusNode: _streetFocusNode,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                key: _cityFieldKey,
                                label: 'City',
                                controller: _cityController,
                                focusNode: _cityFocusNode,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                key: _postalFieldKey,
                                label: 'Postal Code',
                                controller: _postalController,
                                keyboardType: TextInputType.number,
                                focusNode: _postalFocusNode,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          key: _provinceFieldKey,
                          label: 'Province',
                          value: _selectedProvince,
                          items: _saProvinces,
                          onChanged: (value) =>
                              setState(() => _selectedProvince = value),
                        ),
                        const SizedBox(height: 16),
                        _buildStaticField(
                          label: 'Country',
                          value: 'South Africa',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          key: _phoneFieldKey,
                          label: phoneLabel,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          hintText: 'Include country code if needed',
                          focusNode: _phoneFocusNode,
                        ),

                        const SizedBox(height: 32),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 32),

                        Container(
                          key: _shippingSectionKey,
                          child: _buildSectionTitle('Shipping Method'),
                        ),
                        const SizedBox(height: 8),
                        if (enabledOptions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _shippingUnavailableMessage(items.length),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textHint,
                              ),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 16),
                          ...enabledOptions.map(
                            (opt) => _buildShippingTile(opt),
                          ),
                          if (_selectedShipping == 'courier_guy') ...[
                            const SizedBox(height: 8),
                            _buildInfoNote(
                              'Search and select the Courier Guy locker where you want to collect your parcel.',
                            ),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                              label: 'Locker Province',
                              value: _courierGuyLockerProvince,
                              items: _saProvinces,
                              onChanged: (value) {
                                setState(() {
                                  _courierGuyLockerProvince = value;
                                  _selectedCourierGuyLocker = null;
                                  _pickupPointController.clear();
                                });
                                _searchCourierGuyLockers();
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              key: _pickupPointFieldKey,
                              label: 'Search Courier Guy locker',
                              controller: _courierGuySearchController,
                              focusNode: _pickupPointFocusNode,
                              prefixIcon: Icons.search_rounded,
                              hintText:
                                  'Type a mall, suburb, town, or locker code',
                              validator: (_) => null,
                              onChanged: (_) {
                                setState(() => _clearCourierGuyLockerSelection());
                                _scheduleCourierGuyLockerSearch();
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_selectedCourierGuyLocker != null)
                              _buildSelectedCourierGuyLockerCard(),
                            if (_courierGuyLockerError != null) ...[
                              const SizedBox(height: 12),
                              _buildInlineErrorCard(_courierGuyLockerError!),
                            ],
                            if (_isLoadingCourierGuyLockers) ...[
                              const SizedBox(height: 12),
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(
                                    color: AppTheme.terracotta,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ] else if (_courierGuyLockers.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildCourierGuyLockerResults(),
                            ],
                          ] else if (_requiresPickupPoint(_selectedShipping)) ...[
                            const SizedBox(height: 8),
                            _buildInfoNote(
                              'Please enter the pickup point or drop-off location the seller should use for this order.',
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              key: _pickupPointFieldKey,
                              label: _pickupPointLabel(_selectedShipping),
                              controller: _pickupPointController,
                              focusNode: _pickupPointFocusNode,
                              prefixIcon: Icons.pin_drop_outlined,
                              hintText: _pickupPointHint(_selectedShipping),
                            ),
                          ] else if (_isMarketPickup(_selectedShipping)) ...[
                            const SizedBox(height: 8),
                            _buildInfoNote(
                              'For market pickup, please message the seller after checkout to confirm which market, date, and collection time applies to your order.',
                            ),
                          ],
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
                            border: Border.all(
                              color: AppTheme.sand.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              _summaryRow(
                                'Subtotal (${items.length} items)',
                                'R${subtotal.toStringAsFixed(0)}',
                              ),
                              if (giftFee > 0) ...[
                                const SizedBox(height: 12),
                                _summaryRow(
                                  giftServiceLabel,
                                  'R${giftFee.toStringAsFixed(0)}',
                                ),
                              ],
                              const SizedBox(height: 12),
                              _summaryRow(
                                'Shipping',
                                shippingCost == 0
                                    ? 'FREE'
                                    : 'R${shippingCost.toStringAsFixed(0)}',
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Divider(
                                  color: AppTheme.sand.withValues(alpha: 0.3),
                                  height: 1,
                                ),
                              ),
                              _summaryRow(
                                'Total',
                                'R${total.toStringAsFixed(0)}',
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        GradientButton(
                          label: 'Pay Now',
                          isLoading: _isSubmittingPayment,
                          onPressed: () => _submitCheckout(
                            items: items,
                            subtotal: subtotal,
                            giftFee: giftFee,
                            shippingCost: shippingCost,
                            total: total,
                            enabledOptions: enabledOptions,
                          ),
                        ),
                        const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.terracotta,
            strokeWidth: 2,
          ),
        ),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    Key? key,
    required String label,
    required TextEditingController controller,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    String? hintText,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: keyboardType,
      readOnly: readOnly,
      validator:
          validator ??
          (value) => (value == null || value.isEmpty) ? 'Required' : null,
      style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 14),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppTheme.textHint, size: 20)
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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

  Widget _buildDropdownField({
    Key? key,
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: value,
      onChanged: onChanged,
      validator: (selected) =>
          (selected == null || selected.isEmpty) ? 'Required' : null,
      style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
      items: items
          .map(
            (province) => DropdownMenuItem<String>(
              value: province,
              child: Text(province, style: GoogleFonts.poppins(fontSize: 14)),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStaticField({required String label, required String value}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.sand.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.terracotta, width: 1.5),
        ),
      ),
      child: Text(
        value,
        style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildInfoNote(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppTheme.error,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildSelectedCourierGuyLockerCard() {
    final locker = _selectedCourierGuyLocker!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.baobab.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.baobab.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppTheme.baobab,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locker.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locker.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _clearCourierGuyLockerSelection()),
              child: Text(
                'Change locker',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.terracotta,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierGuyLockerResults() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          for (int index = 0; index < _courierGuyLockers.length; index++) ...[
            InkWell(
              onTap: () => _selectCourierGuyLocker(_courierGuyLockers[index]),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? 12 : 0),
                bottom: Radius.circular(
                  index == _courierGuyLockers.length - 1 ? 12 : 0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppTheme.terracotta,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _courierGuyLockers[index].title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _courierGuyLockers[index].subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index != _courierGuyLockers.length - 1)
              Divider(
                height: 1,
                color: AppTheme.sand.withValues(alpha: 0.3),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildShippingTile(ShippingOption option) {
    final isSelected = _selectedShipping == option.key;
    final isFree = option.price == 0;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedShipping = option.key;
        if (option.key != 'courier_guy') {
          _clearCourierGuyLockerSelection();
          _courierGuyLockers = const [];
          _courierGuyLockerError = null;
          _courierGuySearchController.clear();
          _courierGuyLockerProvince = null;
        }
        if (!_requiresPickupPoint(option.key)) {
          _pickupPointController.clear();
        }
      }),
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
            color: isSelected
                ? AppTheme.terracotta
                : AppTheme.sand.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.terracotta.withValues(alpha: 0.05)
                    : AppTheme.scaffoldBg,
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
                      color: isSelected
                          ? AppTheme.terracotta
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
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
              ? GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.sienna,
                )
              : GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
        ),
      ],
    );
  }
}
