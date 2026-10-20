import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../core/pricing/pricing.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/bobgo.dart';
import '../../../models/cart_item.dart';
import '../../../models/checkout_shop_selection.dart';
import '../../../models/courier_guy_locker.dart';
import '../../../models/pargo_pickup_point.dart';
import '../../../models/shipping_option.dart';
import '../../../services/meta_app_events_service.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/skeleton.dart';
import '../providers/bobgo_providers.dart';
import '../providers/buyer_providers.dart';
import '../utils/bobgo_checkout.dart';
import '../utils/checkout_validation.dart';
import '../utils/checkout_shipping_layout.dart';
import '../utils/multi_shop_checkout.dart';
import '../widgets/bobgo_rate_picker.dart';

/// Bob Go door-to-door for one shop: the quote is saved server-side; we only
/// keep its id and the rate the buyer picked.
class _ShopBobGoState {
  BobGoQuote? quote;
  BobGoRate? selectedRate;
  String? quotedFingerprint;
  String? error;
  bool isLoading = false;
  Timer? expiryTimer;

  void clear({bool keepError = false}) {
    expiryTimer?.cancel();
    expiryTimer = null;
    quote = null;
    selectedRate = null;
    quotedFingerprint = null;
    if (!keepError) error = null;
  }
}

/// Pickup point search and choice for one shop's parcel.
class _ShopPickupState {
  final fieldKey = GlobalKey();
  final focusNode = FocusNode();
  final pickupPointController = TextEditingController(text: '');
  final courierGuySearchController = TextEditingController(text: '');
  final pargoSearchController = TextEditingController(text: '');
  String? courierGuyLockerProvince;
  bool isLoadingCourierGuyLockers = false;
  String? courierGuyLockerError;
  CourierGuyLocker? selectedCourierGuyLocker;
  List<CourierGuyLocker> courierGuyLockers = const [];
  Timer? courierGuySearchDebounce;
  String? pargoPointProvince;
  bool isLoadingPargoPoints = false;
  String? pargoPointError;
  PargoPickupPoint? selectedPargoPoint;
  List<PargoPickupPoint> pargoPickupPoints = const [];
  Timer? pargoSearchDebounce;

  void resetCourierGuy() {
    selectedCourierGuyLocker = null;
    courierGuyLockers = const [];
    courierGuyLockerError = null;
    courierGuySearchController.clear();
    courierGuyLockerProvince = null;
  }

  void resetPargo() {
    selectedPargoPoint = null;
    pargoPickupPoints = const [];
    pargoPointError = null;
    pargoSearchController.clear();
    pargoPointProvince = null;
  }

  void dispose() {
    courierGuySearchDebounce?.cancel();
    pargoSearchDebounce?.cancel();
    focusNode.dispose();
    pickupPointController.dispose();
    courierGuySearchController.dispose();
    pargoSearchController.dispose();
  }
}

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

  /// Delivery method per shop id. Each shop sends its own parcel.
  final Map<String, String?> _selectedShippingByShop = {};

  /// Basket shops as last built, in the order they were added.
  List<CartShopGroup> _groups = const [];
  String? _selectedProvince;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _fullNameFieldKey = GlobalKey();
  final _streetFieldKey = GlobalKey();
  final _cityFieldKey = GlobalKey();
  final _postalFieldKey = GlobalKey();
  final _provinceFieldKey = GlobalKey();
  final _phoneFieldKey = GlobalKey();
  final _suburbFieldKey = GlobalKey();
  final _shippingSectionKey = GlobalKey();
  final _nameFocusNode = FocusNode();
  final _streetFocusNode = FocusNode();
  final _cityFocusNode = FocusNode();
  final _postalFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _suburbFocusNode = FocusNode();

  final _nameController = TextEditingController(text: '');
  final _streetController = TextEditingController(text: '');
  final _cityController = TextEditingController(text: '');
  final _postalController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '');
  final _suburbController = TextEditingController(text: '');
  final _couponController = TextEditingController(text: '');
  bool _submitAttempted = false;
  bool _isSubmittingPayment = false;
  bool _isApplyingCoupon = false;
  String? _appliedCouponCode;
  double _discountAmount = 0;

  /// The applied code's saving, under the shop that owns the code.
  Map<String, double> _discountByShop = const {};
  String? _couponError;

  // Bob Go door-to-door, per shop.
  final Map<String, _ShopBobGoState> _bobGoByShop = {};

  void _clearAppliedCoupon() {
    _appliedCouponCode = null;
    _discountAmount = 0;
    _discountByShop = const {};
    _couponError = null;
  }

  bool get _isMultiShop => _groups.length > 1;

  String? _methodFor(String shopId) => _selectedShippingByShop[shopId];

  /// Selected method of every basket shop (null where none is chosen yet).
  List<String?> get _currentMethods => _groups
      .map((group) => _selectedShippingByShop[group.shopId])
      .toList(growable: false);

  bool get _usesBobGo => _currentMethods.contains(bobGoShippingKey);

  bool get _needsShippingAddress =>
      _currentMethods.any(_requiresShippingAddress);

  bool get _needsPickupPoint => _currentMethods.any(_requiresPickupPoint);

  // Pickup point (locker / Pargo point / typed entry), per shop: each shop
  // can send its parcel to a different pickup point.
  final Map<String, _ShopPickupState> _pickupByShop = {};

  _ShopPickupState _pickup(String shopId) =>
      _pickupByShop.putIfAbsent(shopId, _ShopPickupState.new);

  /// First shop whose pickup method still needs a pickup point.
  CartShopGroup? get _shopMissingPickupPoint {
    for (final group in _groups) {
      if (!_requiresPickupPoint(_methodFor(group.shopId))) continue;
      if (_pickup(group.shopId).pickupPointController.text.trim().isEmpty) {
        return group;
      }
    }
    return null;
  }

  /// The `pickup_point` sent for one shop, in the same shape as always.
  Object? _pickupPointFor(String shopId, List<ShippingOption> options) {
    final method = _methodFor(shopId);
    final p = _pickup(shopId);
    return pickupPointForMethod(
      method: method,
      courierGuyLocker: p.selectedCourierGuyLocker?.toOrderJson(),
      pargoPoint: p.selectedPargoPoint?.toOrderJson(),
      marketOption: options
          .where((option) => option.key == 'market_pickup')
          .firstOrNull,
      typedPickupPoint: p.pickupPointController.text,
    );
  }

  _ShopBobGoState _bobGo(String shopId) =>
      _bobGoByShop.putIfAbsent(shopId, _ShopBobGoState.new);

  bool get _allBobGoReady => _groups
      .where((group) => _methodFor(group.shopId) == bobGoShippingKey)
      .every((group) => _bobGoStatus(group.shopId) == BobGoQuoteStatus.ready);

  /// Delivery choice per shop for create-checkout, or null while a shop has
  /// no method chosen.
  List<CheckoutShopSelection>? _shopSelections(
    Map<String, double> shippingByShop,
  ) {
    final selections = <CheckoutShopSelection>[];
    for (final group in _groups) {
      final method = _methodFor(group.shopId);
      if (method == null) return null;
      selections.add(
        CheckoutShopSelection(
          shopId: group.shopId,
          shippingMethod: method,
          shippingCost: shippingByShop[group.shopId] ?? 0,
          bobgo: method == bobGoShippingKey
              ? _bobGoSelection(group.shopId)
              : null,
        ),
      );
    }
    return selections;
  }

  String _couponFailureMessage(Object error) {
    if (error is FunctionException) {
      final details = error.details;
      final serverMessage = details is Map && details['error'] != null
          ? details['error'].toString()
          : null;
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return serverMessage;
      }
    }
    return 'We could not apply this code. Check it and try again.';
  }

  Future<void> _applyCoupon({
    required Map<String, double> shippingByShop,
    required bool isGift,
  }) async {
    if (_isApplyingCoupon) return;
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _clearAppliedCoupon();
        _couponError = 'Enter a discount code first.';
      });
      return;
    }
    final selections = _shopSelections(shippingByShop);
    if (selections == null) {
      setState(
        () => _couponError = _isMultiShop
            ? 'Choose a delivery option for every shop first.'
            : 'Select a shipping method first.',
      );
      return;
    }
    if (_usesBobGo && !_allBobGoReady) {
      setState(
        () =>
            _couponError = 'Choose a delivery service before applying a code.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isApplyingCoupon = true;
      _couponError = null;
    });

    try {
      final quote = await ref
          .read(supabaseServiceProvider)
          .previewCheckout(
            shops: selections,
            isGift: isGift,
            couponCode: code,
            shippingAddress: _usesBobGo ? _bobGoAddressMap() : null,
          );
      if (!mounted) return;
      setState(() {
        _appliedCouponCode = quote.couponCode ?? code;
        _discountAmount = quote.discountAmount;
        _discountByShop = quote.shops.isNotEmpty
            ? quote.discountByShop
            : {
                if (_groups.isNotEmpty && quote.discountAmount > 0)
                  _groups.first.shopId: quote.discountAmount,
              };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clearAppliedCoupon();
        _couponError = _couponFailureMessage(error);
      });
    } finally {
      if (mounted) setState(() => _isApplyingCoupon = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameFocusNode.dispose();
    _streetFocusNode.dispose();
    _cityFocusNode.dispose();
    _postalFocusNode.dispose();
    _phoneFocusNode.dispose();
    _suburbFocusNode.dispose();
    for (final state in _bobGoByShop.values) {
      state.expiryTimer?.cancel();
    }
    for (final state in _pickupByShop.values) {
      state.dispose();
    }
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _phoneController.dispose();
    _suburbController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  /// Picks the first available option for any shop without a valid choice.
  void _initSelections(Map<String, List<ShippingOption>> optionsByShop) {
    final updates = <String, String?>{};
    optionsByShop.forEach((shopId, options) {
      final current = _selectedShippingByShop[shopId];
      final valid =
          current != null && options.any((option) => option.key == current);
      if (valid) return;
      final next = options.isNotEmpty ? options.first.key : null;
      if (next != current || !_selectedShippingByShop.containsKey(shopId)) {
        updates[shopId] = next;
      }
    });
    if (updates.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedShippingByShop.addAll(updates));
    });
  }

  String _shippingUnavailableMessage(int itemCount) {
    if (itemCount <= 1) {
      return 'This product does not have any shipping options available yet.';
    }
    return 'The products in this basket do not share an available shipping option yet.';
  }

  bool _requiresPickupPoint(String? shippingMethod) {
    return shippingMethod == 'courier_guy' || shippingMethod == 'pargo';
  }

  bool _requiresShippingAddress(String? shippingMethod) {
    return shippingMethod == 'courier_guy_door_to_door' ||
        shippingMethod == bobGoShippingKey;
  }

  BobGoDeliveryDetails _bobGoDetails() => BobGoDeliveryDetails(
    fullName: _nameController.text,
    phone: _phoneController.text,
    streetAddress: _streetController.text,
    localArea: _suburbController.text,
    city: _cityController.text,
    province: _selectedProvince ?? '',
    postalCode: _postalController.text,
  );

  BobGoSelection? _bobGoSelection(String shopId) {
    final state = _bobGoByShop[shopId];
    return state != null && _bobGoStatus(shopId) == BobGoQuoteStatus.ready
        ? BobGoSelection(
            quoteId: state.quote!.quoteId,
            rate: state.selectedRate!,
          )
        : null;
  }

  /// Address sent to create-checkout. `local_area` must match the quoted
  /// suburb exactly or the server rejects the saved quote.
  Map<String, dynamic> _bobGoAddressMap() => {
    'name': _nameController.text,
    'country': 'South Africa',
    'phone': _phoneController.text,
    'street': _streetController.text,
    'local_area': _suburbController.text,
    'city': _cityController.text,
    'postal_code': _postalController.text,
    'province': _selectedProvince,
  };

  BobGoQuoteStatus _bobGoStatus(String shopId) {
    final state = _bobGoByShop[shopId];
    return bobGoQuoteStatus(
      quote: state?.quote,
      selectedRate: state?.selectedRate,
      quotedFingerprint: state?.quotedFingerprint,
      currentFingerprint: _bobGoDetails().fingerprint,
      now: DateTime.now(),
    );
  }

  bool get _bobGoAddressComplete =>
      _streetController.text.trim().isNotEmpty &&
      _suburbController.text.trim().isNotEmpty &&
      _cityController.text.trim().isNotEmpty &&
      _postalController.text.trim().isNotEmpty &&
      (_selectedProvince ?? '').isNotEmpty &&
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty;

  /// Quotes Bob Go for one shop's items only (each shop sends its own parcel).
  Future<void> _requestBobGoRates(String shopId) async {
    final state = _bobGo(shopId);
    if (state.isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      state.clear();
      state.isLoading = true;
      _clearAppliedCoupon();
    });
    final details = _bobGoDetails();
    try {
      final quote = await ref
          .read(bobGoGatewayProvider)
          .requestQuote(details, shopId: shopId.isEmpty ? null : shopId);
      if (!mounted) return;
      setState(() {
        state.quote = quote;
        state.quotedFingerprint = details.fingerprint;
        state.selectedRate = quote.rates.length == 1 ? quote.rates.first : null;
      });
      _scheduleBobGoExpiry(state, quote);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        state.error = error is BobGoQuoteException
            ? error.message
            : 'We could not get delivery rates right now. Please try again.';
      });
    } finally {
      if (mounted) setState(() => state.isLoading = false);
    }
  }

  void _scheduleBobGoExpiry(_ShopBobGoState state, BobGoQuote quote) {
    state.expiryTimer?.cancel();
    final expiry = quote.expiresAt;
    if (expiry == null) return;
    final wait = expiry.difference(DateTime.now());
    state.expiryTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      // Rebuild so the picker and Pay button reflect the expired quote.
      if (mounted) setState(_clearAppliedCoupon);
    });
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

  String _pargoPointSummary(PargoPickupPoint point) {
    return [
      point.title,
      if (point.address.isNotEmpty) point.address,
      if (point.province.isNotEmpty) point.province,
    ].join(' • ');
  }

  String _marketPickupSummary(ShippingOption option) {
    return [
      option.marketName,
      option.marketLocation,
      option.marketProvince,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' • ');
  }

  void _clearCourierGuyLockerSelection(_ShopPickupState p) {
    p.selectedCourierGuyLocker = null;
    p.pickupPointController.clear();
  }

  void _clearPargoPointSelection(_ShopPickupState p) {
    p.selectedPargoPoint = null;
    p.pickupPointController.clear();
  }

  Future<void> _searchCourierGuyLockers(_ShopPickupState p) async {
    final search = p.courierGuySearchController.text.trim();
    final province = p.courierGuyLockerProvince?.trim();
    if (search.length < 2 && (province == null || province.isEmpty)) {
      if (!mounted) return;
      setState(() {
        p.courierGuyLockers = const [];
        p.courierGuyLockerError = null;
        p.isLoadingCourierGuyLockers = false;
      });
      return;
    }

    setState(() {
      p.isLoadingCourierGuyLockers = true;
      p.courierGuyLockerError = null;
    });

    try {
      final lockers = await ref
          .read(supabaseServiceProvider)
          .searchCourierGuyLockers(query: search, province: province);
      if (!mounted) return;
      setState(() {
        p.courierGuyLockers = lockers;
        p.isLoadingCourierGuyLockers = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[locker-debug] checkout screen search failed query="$search" province="$province" error=$error stackTrace=$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        p.courierGuyLockers = const [];
        p.courierGuyLockerError =
            'Could not load Courier Guy lockers right now. Try again in a moment.';
        p.isLoadingCourierGuyLockers = false;
      });
    }
  }

  void _scheduleCourierGuyLockerSearch(_ShopPickupState p) {
    p.courierGuySearchDebounce?.cancel();
    p.courierGuySearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchCourierGuyLockers(p),
    );
  }

  void _selectCourierGuyLocker(_ShopPickupState p, CourierGuyLocker locker) {
    setState(() {
      p.selectedCourierGuyLocker = locker;
      p.pickupPointController.text = _courierGuyLockerSummary(locker);
      p.courierGuyLockers = const [];
      p.courierGuyLockerError = null;
    });
  }

  Future<void> _searchPargoPickupPoints(_ShopPickupState p) async {
    final search = p.pargoSearchController.text.trim();
    final province = p.pargoPointProvince?.trim();
    if (search.length < 2 && (province == null || province.isEmpty)) {
      if (!mounted) return;
      setState(() {
        p.pargoPickupPoints = const [];
        p.pargoPointError = null;
        p.isLoadingPargoPoints = false;
      });
      return;
    }

    setState(() {
      p.isLoadingPargoPoints = true;
      p.pargoPointError = null;
    });

    try {
      final points = await ref
          .read(supabaseServiceProvider)
          .searchPargoPickupPoints(query: search, province: province);
      if (!mounted) return;
      setState(() {
        p.pargoPickupPoints = points;
        p.isLoadingPargoPoints = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        p.pargoPickupPoints = const [];
        p.pargoPointError =
            'Could not load Pargo pickup points right now. Try again in a moment.';
        p.isLoadingPargoPoints = false;
      });
    }
  }

  void _schedulePargoPickupPointSearch(_ShopPickupState p) {
    p.pargoSearchDebounce?.cancel();
    p.pargoSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchPargoPickupPoints(p),
    );
  }

  void _selectPargoPickupPoint(_ShopPickupState p, PargoPickupPoint point) {
    setState(() {
      p.selectedPargoPoint = point;
      p.pickupPointController.text = _pargoPointSummary(point);
      p.pargoPickupPoints = const [];
      p.pargoPointError = null;
    });
  }

  CheckoutFormSnapshot _checkoutSnapshot(
    Map<String, List<ShippingOption>> optionsByShop,
  ) {
    final methods = _currentMethods;
    return CheckoutFormSnapshot(
      fullName: _nameController.text,
      streetAddress: _streetController.text,
      city: _cityController.text,
      postalCode: _postalController.text,
      province: _selectedProvince,
      phoneNumber: _phoneController.text,
      // Every shop needs a method; report "none" while any shop lacks one.
      selectedShippingMethod: methods.isEmpty || methods.contains(null)
          ? null
          : methods.first,
      hasAvailableShippingMethods: _groups.every(
        (group) => (optionsByShop[group.shopId] ?? const []).isNotEmpty,
      ),
      requiresShippingAddress: _needsShippingAddress,
      requiresPickupPoint: _needsPickupPoint,
      // Every shop using a pickup method needs its own pickup point.
      pickupPoint: _shopMissingPickupPoint == null ? 'chosen' : '',
      requiresSuburb: _usesBobGo,
      suburb: _suburbController.text,
      requiresBobGoRate: _usesBobGo,
      hasUsableBobGoRate: _allBobGoReady,
    );
  }

  Future<void> _ensureFieldVisible(CheckoutField field) async {
    final missingPickupShop = _shopMissingPickupPoint;
    final p = _pickup(
      missingPickupShop?.shopId ?? _groups.firstOrNull?.shopId ?? '',
    );
    final context = switch (field) {
      CheckoutField.fullName => _fullNameFieldKey.currentContext,
      CheckoutField.streetAddress => _streetFieldKey.currentContext,
      CheckoutField.city => _cityFieldKey.currentContext,
      CheckoutField.postalCode => _postalFieldKey.currentContext,
      CheckoutField.province => _provinceFieldKey.currentContext,
      CheckoutField.phoneNumber => _phoneFieldKey.currentContext,
      CheckoutField.shippingMethod => _shippingSectionKey.currentContext,
      CheckoutField.pickupPoint => p.fieldKey.currentContext,
      CheckoutField.suburb => _suburbFieldKey.currentContext,
      CheckoutField.bobGoRate => _shippingSectionKey.currentContext,
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
        p.focusNode.requestFocus();
        break;
      case CheckoutField.suburb:
        _suburbFocusNode.requestFocus();
        break;
      case CheckoutField.bobGoRate:
      case CheckoutField.province:
      case CheckoutField.shippingMethod:
        FocusScope.of(this.context).unfocus();
        break;
    }
  }

  String _blockingMessage(CheckoutField field) {
    if (_isMultiShop) {
      if (field == CheckoutField.shippingMethod) {
        return 'A shop in your basket has no delivery option for these products yet. Remove its items to continue.';
      }
      if (field == CheckoutField.bobGoRate) {
        return 'Get delivery rates and choose a courier service for each shop using Bob Go.';
      }
    }
    return checkoutBlockingMessage(field);
  }

  Future<void> _showBlockingFeedback(CheckoutField field) async {
    if (mounted) {
      setState(() => _submitAttempted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _blockingMessage(field),
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
    required List<CartItem> items,
    required CheckoutTotals totals,
    required Map<String, double> shippingByShop,
    required Map<String, List<ShippingOption>> optionsByShop,
  }) async {
    if (_isSubmittingPayment) return;

    final enteredCoupon = _couponController.text.trim().toUpperCase();
    if (enteredCoupon.isNotEmpty && enteredCoupon != _appliedCouponCode) {
      setState(() => _couponError = 'Tap Apply before continuing to payment.');
      return;
    }

    final incompleteField = firstIncompleteCheckoutField(
      _checkoutSnapshot(optionsByShop),
    );
    if (incompleteField != null) {
      await _showBlockingFeedback(incompleteField);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _submitAttempted = true);
      return;
    }

    var selections = _shopSelections(shippingByShop);
    if (selections == null) {
      await _showBlockingFeedback(CheckoutField.shippingMethod);
      return;
    }

    setState(() {
      _submitAttempted = true;
      _isSubmittingPayment = true;
    });

    final address = <String, dynamic>{
      'name': _nameController.text,
      'country': 'South Africa',
      'phone': _phoneController.text,
      if (_needsShippingAddress) ...{
        'street': _streetController.text,
        'city': _cityController.text,
        'postal_code': _postalController.text,
        'province': _selectedProvince,
        if (_usesBobGo) 'local_area': _suburbController.text,
      },
    };
    if (selections.length == 1) {
      // One shop: exactly as before, the pickup point sits in the address.
      final pickupPoint = _pickupPointFor(
        _groups.first.shopId,
        optionsByShop[_groups.first.shopId] ?? const [],
      );
      if (pickupPoint != null) address['pickup_point'] = pickupPoint;
    } else {
      // Several shops: each shop's pickup point goes with that shop only.
      selections = [
        for (final selection in selections)
          () {
            final pickupPoint = _pickupPointFor(
              selection.shopId,
              optionsByShop[selection.shopId] ?? const [],
            );
            return pickupPoint == null
                ? selection
                : selection.copyWith(
                    shippingAddress: {'pickup_point': pickupPoint},
                  );
          }(),
      ];
    }

    final single = selections.length == 1 ? selections.single : null;
    final checkoutData = {
      'items': items,
      'subtotal': totals.subtotal,
      'giftFee': totals.giftFee,
      'shippingCost': totals.shippingCost,
      'shippingMethod': single?.shippingMethod,
      'total': totals.total,
      'couponCode': _appliedCouponCode,
      'address': address,
      if (single?.bobgo != null) 'bobgo': single!.bobgo,
      'shops': selections,
      'shopTotals': totals.shops,
    };

    try {
      await ref
          .read(metaAppEventsServiceProvider)
          .logInitiatedCheckout(
            items: items,
            totalPrice: totals.total,
            shippingMethod:
                single?.shippingMethod ??
                selections.map((shop) => shop.shippingMethod).join(','),
          );
      if (!mounted) return;
      await context.push('/cart/payment', extra: checkoutData);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingPayment = false);
      }
    }
  }

  Widget? _stickyPayBar;

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartItemsProvider);
    _groups = groupCartItemsByShop(cartAsync.asData?.value ?? const []);
    final giftOptions = ref.watch(giftOptionsProvider);
    final isGift = giftOptions.isGift;
    final requiresShippingAddress = _needsShippingAddress;
    final addressTitle = requiresShippingAddress
        ? (isGift ? 'Recipient Delivery Details' : 'Shipping Address')
        : 'Contact Details';
    final nameLabel = isGift ? 'Recipient Full Name' : 'Full Name';
    final phoneLabel = isGift ? 'Recipient Phone Number' : 'Phone Number';
    _stickyPayBar = null;

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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.bone.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 30,
                        color: AppTheme.textHint,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your basket is empty',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add something handmade before you check out.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => context.go('/home'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.terracotta,
                        side: const BorderSide(color: AppTheme.terracotta),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: Text(
                        'Start shopping',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final groups = _groups;
          final optionsByShop = <String, List<ShippingOption>>{};
          final shippingByShop = <String, double>{};
          for (final group in groups) {
            final shopId = group.shopId;
            // Combined shipping is a per-shop setting.
            final combinedShippingEnabled = shopId.isEmpty
                ? true
                : ref
                          .watch(shopDetailProvider(shopId))
                          .asData
                          ?.value
                          .combinedShippingEnabled ??
                      true;
            final bobGoAvailable =
                shopId.isNotEmpty &&
                (ref
                        .watch(bobGoShopAvailabilityProvider(shopId))
                        .asData
                        ?.value ??
                    false);
            final bobGoRate = _bobGoByShop[shopId]?.selectedRate;
            final bobGoReady = _bobGoStatus(shopId) == BobGoQuoteStatus.ready;
            optionsByShop[shopId] = [
              ...group.availableShippingOptions,
              if (bobGoAvailable)
                ShippingOption(
                  key: bobGoShippingKey,
                  enabled: true,
                  price: bobGoRate?.amount ?? 0,
                ),
            ];
            shippingByShop[shopId] = shopShippingCost(
              group: group,
              methodKey: _methodFor(shopId),
              combinedShippingEnabled: combinedShippingEnabled,
              bobGoAmount: bobGoReady ? bobGoRate!.amount : 0,
            );
          }
          _initSelections(optionsByShop);

          final totals = calculateShopTotals(
            groups: groups,
            shippingByShop: shippingByShop,
            isGift: isGift,
            discountByShop: _discountByShop,
          );

          _stickyPayBar = _buildStickyPayBar(
            total: totals.total,
            onPressed: () => _submitCheckout(
              items: items,
              totals: totals,
              shippingByShop: shippingByShop,
              optionsByShop: optionsByShop,
            ),
          );

          return SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                    if (requiresShippingAddress) ...[
                      _buildInfoNote(
                        'Orders can be placed from abroad, but delivery addresses must be within South Africa.',
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      _buildInfoNote(
                        'We only need your name and phone number for this collection method. No delivery address is required.',
                      ),
                      const SizedBox(height: 24),
                    ],

                    _buildTextField(
                      key: _fullNameFieldKey,
                      label: nameLabel,
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                    ),
                    if (requiresShippingAddress) ...[
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
                      if (_usesBobGo) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          key: _suburbFieldKey,
                          label: 'Suburb',
                          controller: _suburbController,
                          focusNode: _suburbFocusNode,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
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
                    ],
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
                      child: _buildSectionTitle(
                        _isMultiShop ? 'Delivery' : 'Shipping Method',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isMultiShop) ...[
                      const SizedBox(height: 8),
                      _buildInfoNote(
                        'Your basket has items from ${groups.length} shops. '
                        'Each shop sends its own parcel, so choose delivery '
                        'for each one. You still pay once for everything.',
                      ),
                      const SizedBox(height: 24),
                      for (var index = 0; index < groups.length; index++) ...[
                        if (index > 0) ...[
                          Divider(
                            height: 1,
                            color: AppTheme.sand.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _buildShopDeliverySection(
                          groups[index],
                          optionsByShop[groups[index].shopId] ?? const [],
                        ),
                      ],
                    ] else
                      ..._buildShopShippingOptions(
                        groups.first,
                        optionsByShop[groups.first.shopId] ?? const [],
                      ),

                    const SizedBox(height: 32),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 32),

                    _buildSectionTitle('Order Summary'),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _couponController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  maxLength: 32,
                                  onChanged: (value) {
                                    final normalized = value
                                        .trim()
                                        .toUpperCase();
                                    if (_appliedCouponCode != null &&
                                        normalized != _appliedCouponCode) {
                                      setState(_clearAppliedCoupon);
                                    } else if (_couponError != null) {
                                      setState(() => _couponError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Discount code (optional)',
                                    hintText: 'Enter shop code',
                                    counterText: '',
                                    prefixIcon: const Icon(Icons.sell_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 56,
                                child: FilledButton(
                                  onPressed: _isApplyingCoupon
                                      ? null
                                      : () => _applyCoupon(
                                          shippingByShop: shippingByShop,
                                          isGift: isGift,
                                        ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.terracotta,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isApplyingCoupon
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Apply'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_couponError != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _couponError!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.error,
                                ),
                              ),
                            )
                          else if (_appliedCouponCode != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF7EE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: Color(0xFF247A3D),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$_appliedCouponCode applied — you save R${_discountAmount.toStringAsFixed(2)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF247A3D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              'Apply the code to confirm the saving before payment.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (_isMultiShop)
                            ..._buildMultiShopSummary(totals, isGift: isGift)
                          else ...[
                            _summaryRow(
                              'Subtotal (${items.length} items)',
                              'R${totals.subtotal.toStringAsFixed(0)}',
                            ),
                            if (totals.discountAmount > 0) ...[
                              const SizedBox(height: 12),
                              _summaryRow(
                                'Discount ($_appliedCouponCode)',
                                '-R${totals.discountAmount.toStringAsFixed(2)}',
                              ),
                            ],
                            if (totals.giftFee > 0) ...[
                              const SizedBox(height: 12),
                              _summaryRow(
                                giftServiceLabel,
                                'R${totals.giftFee.toStringAsFixed(0)}',
                              ),
                            ],
                            const SizedBox(height: 12),
                            _summaryRow(
                              'Shipping',
                              _shippingDisplay(
                                groups.first.shopId,
                                totals.shippingCost,
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(
                              color: AppTheme.sand.withValues(alpha: 0.3),
                              height: 1,
                            ),
                          ),
                          _summaryRow(
                            'Total',
                            'R${totals.total.toStringAsFixed(0)}',
                            isTotal: true,
                          ),
                          if (_isMultiShop) ...[
                            const SizedBox(height: 12),
                            Text(
                              'One payment covers every shop. $wholeRandPaymentNote',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textHint,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => _buildLoadingSkeleton(),
        error: (error, _) => ErrorRetryView(
          error: error,
          title: "Couldn't load checkout",
          onRetry: () => ref.invalidate(cartItemsProvider),
        ),
      ),
      bottomNavigationBar: _stickyPayBar,
    );
  }

  Widget _buildLoadingSkeleton() {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SkeletonBox(width: 160, height: 20, radius: 8),
          const SizedBox(height: 16),
          SkeletonBox(width: double.infinity, height: 56, radius: 12),
          const SizedBox(height: 16),
          SkeletonBox(width: double.infinity, height: 56, radius: 12),
          const SizedBox(height: 24),
          SkeletonBox(width: 160, height: 20, radius: 8),
          const SizedBox(height: 16),
          SkeletonBox(width: double.infinity, height: 76, radius: 20),
          const SizedBox(height: 24),
          SkeletonBox(width: double.infinity, height: 220, radius: 20),
        ],
      ),
    );
  }

  Widget _buildStickyPayBar({
    required double total,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          top: BorderSide(color: AppTheme.sand.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      'R${total.toStringAsFixed(0)}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: 'Pay Now',
                  isLoading: _isSubmittingPayment,
                  borderRadius: 26,
                  verticalPadding: 14,
                  onPressed: onPressed,
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildSelectedCourierGuyLockerCard(_ShopPickupState p) {
    final locker = p.selectedCourierGuyLocker!;
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
              onPressed: () =>
                  setState(() => _clearCourierGuyLockerSelection(p)),
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

  Widget _buildCourierGuyLockerResults(_ShopPickupState p) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          for (int index = 0; index < p.courierGuyLockers.length; index++) ...[
            InkWell(
              onTap: () =>
                  _selectCourierGuyLocker(p, p.courierGuyLockers[index]),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? 12 : 0),
                bottom: Radius.circular(
                  index == p.courierGuyLockers.length - 1 ? 12 : 0,
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
                            p.courierGuyLockers[index].title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.courierGuyLockers[index].subtitle,
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
            if (index != p.courierGuyLockers.length - 1)
              Divider(height: 1, color: AppTheme.sand.withValues(alpha: 0.3)),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedPargoPointCard(_ShopPickupState p) {
    final point = p.selectedPargoPoint!;
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
                      point.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.subtitle,
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
              onPressed: () => setState(() => _clearPargoPointSelection(p)),
              child: Text(
                'Change pickup point',
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

  Widget _buildPargoPickupPointResults(_ShopPickupState p) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          for (int index = 0; index < p.pargoPickupPoints.length; index++) ...[
            InkWell(
              onTap: () =>
                  _selectPargoPickupPoint(p, p.pargoPickupPoints[index]),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(index == 0 ? 12 : 0),
                bottom: Radius.circular(
                  index == p.pargoPickupPoints.length - 1 ? 12 : 0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.store_mall_directory_outlined,
                      size: 18,
                      color: AppTheme.terracotta,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.pargoPickupPoints[index].title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.pargoPickupPoints[index].subtitle,
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
            if (index != p.pargoPickupPoints.length - 1)
              Divider(height: 1, color: AppTheme.sand.withValues(alpha: 0.3)),
          ],
        ],
      ),
    );
  }

  /// "R65", "FREE", "R95.00 incl. VAT" or a prompt, for one shop's shipping.
  String _shippingDisplay(String shopId, double cost) {
    final method = _methodFor(shopId);
    if (method == null) return 'Choose delivery';
    if (method == bobGoShippingKey) {
      return _bobGoStatus(shopId) == BobGoQuoteStatus.ready
          ? '${formatBobGoPrice(cost)} incl. VAT'
          : 'Get rates';
    }
    return cost == 0 ? 'FREE' : 'R${cost.toStringAsFixed(0)}';
  }

  /// The option tiles for one shop (or a note when it has none).
  List<Widget> _buildShopShippingOptions(
    CartShopGroup group,
    List<ShippingOption> options,
  ) {
    if (options.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            _shippingUnavailableMessage(group.items.length),
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textHint),
          ),
        ),
      ];
    }
    return [
      const SizedBox(height: 16),
      ...options.map((option) => _buildShippingTile(group.shopId, option)),
    ];
  }

  /// One shop's items and delivery choice in a several-shop basket.
  Widget _buildShopDeliverySection(
    CartShopGroup group,
    List<ShippingOption> options,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.terracotta.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: AppTheme.terracotta,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.shopName,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              'R${group.subtotal.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final item in group.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    [
                      item.product?.title ?? 'Product',
                      if (item.variantName != null) item.variantName!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '× ${item.quantity}',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Delivery from ${group.shopName}',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        ..._buildShopShippingOptions(group, options),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Per-shop totals for a several-shop basket (the grand total follows).
  List<Widget> _buildMultiShopSummary(
    CheckoutTotals totals, {
    required bool isGift,
  }) {
    final widgets = <Widget>[];
    for (var index = 0; index < totals.shops.length; index++) {
      final shop = totals.shops[index];
      final group = _groups.where((g) => g.shopId == shop.shopId).firstOrNull;
      final pieces = group?.itemCount ?? 0;
      if (index > 0) widgets.add(const SizedBox(height: 20));
      widgets.addAll([
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            shop.shopName,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _summaryRow('Items ($pieces)', 'R${shop.subtotal.toStringAsFixed(0)}'),
        if (shop.discountAmount > 0) ...[
          const SizedBox(height: 8),
          _summaryRow(
            'Discount ($_appliedCouponCode)',
            '-R${shop.discountAmount.toStringAsFixed(2)}',
          ),
        ],
        const SizedBox(height: 8),
        _summaryRow(
          'Shipping',
          _shippingDisplay(shop.shopId, shop.shippingCost),
        ),
        if (shop.giftFee > 0) ...[
          const SizedBox(height: 8),
          _summaryRow(giftServiceLabel, 'R${shop.giftFee.toStringAsFixed(0)}'),
        ],
        const SizedBox(height: 8),
        _summaryRow('Shop total', 'R${shop.total.toStringAsFixed(0)}'),
      ]);
    }
    if (isGift) {
      widgets.addAll([
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$giftServiceLabel is R${giftServiceFee.toStringAsFixed(0)} per '
            'shop, because each shop wraps its own parcel.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textHint,
              height: 1.45,
            ),
          ),
        ),
      ]);
    }
    return widgets;
  }

  void _selectShipping(String shopId, String methodKey) {
    setState(() {
      if (_methodFor(shopId) != methodKey) {
        _clearAppliedCoupon();
      }
      _selectedShippingByShop[shopId] = methodKey;
      // Each shop keeps its own pickup point.
      final p = _pickup(shopId);
      if (methodKey != 'courier_guy') {
        _clearCourierGuyLockerSelection(p);
        p.resetCourierGuy();
      }
      if (methodKey != 'pargo') {
        _clearPargoPointSelection(p);
        p.resetPargo();
      }
      if (!_requiresPickupPoint(methodKey)) {
        p.pickupPointController.clear();
      }
      if (methodKey != bobGoShippingKey) {
        _bobGoByShop[shopId]?.clear();
      }
    });
  }

  Widget _buildShippingTile(String shopId, ShippingOption option) {
    final isSelected = _methodFor(shopId) == option.key;
    final isFree = option.price == 0;

    return GestureDetector(
      onTap: () => _selectShipping(shopId, option.key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
        child: Column(
          children: [
            Row(
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
                  option.key == bobGoShippingKey
                      ? (_bobGoByShop[shopId]?.selectedRate == null
                            ? 'Get rates'
                            : formatBobGoPrice(option.price))
                      : isFree
                      ? 'FREE'
                      : 'R${option.price.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isFree && option.key != bobGoShippingKey
                        ? AppTheme.baobab
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 16),
              _buildSelectedShippingInlineDetails(shopId, option),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedShippingInlineDetails(
    String shopId,
    ShippingOption option,
  ) {
    final shippingMethod = option.key;
    final details = inlineDetailsForShippingMethod(shippingMethod);
    final p = _pickup(shopId);
    switch (details) {
      case CheckoutShippingInlineDetails.courierGuyLockerSearch:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoNote(
              'Search and select the Courier Guy locker where you want to collect your parcel.',
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Locker Province',
              value: p.courierGuyLockerProvince,
              items: _saProvinces,
              onChanged: (value) {
                setState(() {
                  p.courierGuyLockerProvince = value;
                  p.selectedCourierGuyLocker = null;
                  p.pickupPointController.clear();
                });
                _searchCourierGuyLockers(p);
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              key: p.fieldKey,
              label: 'Search Courier Guy locker',
              controller: p.courierGuySearchController,
              focusNode: p.focusNode,
              prefixIcon: Icons.search_rounded,
              hintText: 'Type a mall, suburb, town, or locker code',
              validator: (_) => null,
              onChanged: (_) {
                setState(() => _clearCourierGuyLockerSelection(p));
                _scheduleCourierGuyLockerSearch(p);
              },
            ),
            const SizedBox(height: 12),
            if (p.selectedCourierGuyLocker != null)
              _buildSelectedCourierGuyLockerCard(p),
            if (p.courierGuyLockerError != null) ...[
              const SizedBox(height: 12),
              _buildInlineErrorCard(p.courierGuyLockerError!),
            ],
            if (p.isLoadingCourierGuyLockers) ...[
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
            ] else if (p.courierGuyLockers.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildCourierGuyLockerResults(p),
            ],
          ],
        );
      case CheckoutShippingInlineDetails.pargoPickupPointSearch:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoNote(
              'Search and select the Pargo pickup point where you want to collect your parcel.',
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Pickup Point Province',
              value: p.pargoPointProvince,
              items: _saProvinces,
              onChanged: (value) {
                setState(() {
                  p.pargoPointProvince = value;
                  p.selectedPargoPoint = null;
                  p.pickupPointController.clear();
                });
                _searchPargoPickupPoints(p);
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              key: p.fieldKey,
              label: 'Search Pargo pickup point',
              controller: p.pargoSearchController,
              focusNode: p.focusNode,
              prefixIcon: Icons.search_rounded,
              hintText: 'Type a store, suburb, town, or point code',
              validator: (_) => null,
              onChanged: (_) {
                setState(() => _clearPargoPointSelection(p));
                _schedulePargoPickupPointSearch(p);
              },
            ),
            const SizedBox(height: 12),
            if (p.selectedPargoPoint != null) _buildSelectedPargoPointCard(p),
            if (p.pargoPointError != null) ...[
              const SizedBox(height: 12),
              _buildInlineErrorCard(p.pargoPointError!),
            ],
            if (p.isLoadingPargoPoints) ...[
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
            ] else if (p.pargoPickupPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPargoPickupPointResults(p),
            ],
          ],
        );
      case CheckoutShippingInlineDetails.pickupPointEntry:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoNote(
              'Please enter the pickup point or drop-off location the seller should use for this order.',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              key: p.fieldKey,
              label: _pickupPointLabel(shippingMethod),
              controller: p.pickupPointController,
              focusNode: p.focusNode,
              prefixIcon: Icons.pin_drop_outlined,
              hintText: _pickupPointHint(shippingMethod),
            ),
          ],
        );
      case CheckoutShippingInlineDetails.marketPickupNote:
        final marketSummary = _marketPickupSummary(option);
        return _buildInfoNote(
          marketSummary.isEmpty
              ? 'For market pickup, please message the seller after checkout to confirm which market, date, and collection time applies to your order.'
              : 'Market pickup: $marketSummary. Please only choose this if you can collect from this market.',
        );
      case CheckoutShippingInlineDetails.bobGoRates:
        final state = _bobGo(shopId);
        return BobGoRatePicker(
          status: _bobGoStatus(shopId),
          quote: state.quote,
          selectedRate: state.selectedRate,
          isLoading: state.isLoading,
          errorMessage: state.error,
          canRequest: _bobGoAddressComplete,
          now: DateTime.now(),
          onRequest: () => _requestBobGoRates(shopId),
          onSelect: (rate) => setState(() {
            state.selectedRate = rate;
            state.error = null;
            _clearAppliedCoupon();
          }),
        );
      case CheckoutShippingInlineDetails.none:
        return const SizedBox.shrink();
    }
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
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
        ),
      ],
    );
  }
}
