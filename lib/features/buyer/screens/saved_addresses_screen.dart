import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_fab.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/buyer_providers.dart';

class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  ConsumerState<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final addresses = await service.getSavedAddresses(Supabase.instance.client.auth.currentUser!.id);
      if (mounted) setState(() { _addresses = addresses; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAddresses() async {
    final service = ref.read(supabaseServiceProvider);
    await service.saveAddresses(Supabase.instance.client.auth.currentUser!.id, _addresses);
  }

  void _showAddressSheet({Map<String, dynamic>? existing, int? index}) {
    final nameC = TextEditingController(text: existing?['name'] ?? '');
    final streetC = TextEditingController(text: existing?['street'] ?? '');
    final cityC = TextEditingController(text: existing?['city'] ?? '');
    final postalC = TextEditingController(text: existing?['postal_code'] ?? '');
    final provinceC = TextEditingController(text: existing?['province'] ?? '');
    final phoneC = TextEditingController(text: existing?['phone'] ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: AppTheme.scaffoldBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: AppTheme.sand, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    existing != null ? 'Edit Address' : 'Add Address',
                    style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  _field('Full Name', nameC),
                  _field('Street Address', streetC),
                  Row(children: [
                    Expanded(child: _field('City', cityC)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Postal Code', postalC, type: TextInputType.number)),
                  ]),
                  _field('Province', provinceC),
                  _field('Phone', phoneC, type: TextInputType.phone),
                  const SizedBox(height: 8),
                  GradientButton(
                    label: 'Save Address',
                    verticalPadding: 16,
                    borderRadius: 14,
                    fontSize: 15,
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final addr = {
                        'name': nameC.text,
                        'street': streetC.text,
                        'city': cityC.text,
                        'postal_code': postalC.text,
                        'province': provinceC.text,
                        'phone': phoneC.text,
                        'is_default': existing?['is_default'] ?? _addresses.isEmpty,
                      };
                      setState(() {
                        if (index != null) {
                          _addresses[index] = addr;
                        } else {
                          _addresses.add(addr);
                        }
                      });
                      _saveAddresses();
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: AppTheme.textHint, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.sand.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.terracotta, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Saved Addresses',
          style: GoogleFonts.playfairDisplay(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 24),
        ),
        centerTitle: true,
      ),
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        onTap: () => _showAddressSheet(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2))
          : _addresses.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _addressCard(index),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(color: AppTheme.bone.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(Icons.location_on_outlined, size: 40, color: AppTheme.textHint),
            ),
            const SizedBox(height: 24),
            Text('No Saved Addresses', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Text('Add a shipping address to speed up checkout.', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary, height: 1.6), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _addressCard(int index) {
    final addr = _addresses[index];
    final isDefault = addr['is_default'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDefault ? AppTheme.terracotta.withValues(alpha: 0.3) : AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  addr['name'] ?? '',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.terracotta.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text('Default', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.terracotta)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${addr['street']}', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          Text('${addr['city']}, ${addr['province']} ${addr['postal_code']}', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          Text('${addr['phone']}', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isDefault)
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (int i = 0; i < _addresses.length; i++) {
                        _addresses[i] = {..._addresses[i], 'is_default': i == index};
                      }
                    });
                    _saveAddresses();
                  },
                  child: Text('Set as Default', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.terracotta)),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textHint),
                onPressed: () => _showAddressSheet(existing: addr, index: index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                onPressed: () {
                  setState(() => _addresses.removeAt(index));
                  _saveAddresses();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
