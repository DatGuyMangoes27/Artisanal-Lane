import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product.dart';
import '../providers/vendor_providers.dart';

class PostProductPicker extends ConsumerWidget {
  const PostProductPicker({
    super.key,
    required this.ids,
    required this.onChanged,
  });
  final List<String> ids;
  final ValueChanged<List<String>> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(vendorProductsProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(vendorProductsProvider),
          child: const Text('Retry your products'),
        ),
        data: (products) {
          final byId = {for (final p in products) p.id: p};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Link a product (optional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Buyers see a "Shop this piece" button under your post that '
                'opens the product. Link up to five published pieces from '
                'your shop.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: ids
                    .map(
                      (id) => InputChip(
                        label: Text(
                          byId[id]?.title ?? 'Unavailable product',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () => onChanged(
                          ids.where((value) => value != id).toList(),
                        ),
                      ),
                    )
                    .toList(),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: Text('Choose products (${ids.length}/5)'),
                onPressed: () async {
                  final result = await showModalBottomSheet<List<String>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _ProductSelection(
                      products: products.where((p) => p.isPublished).toList(),
                      selected: ids,
                    ),
                  );
                  if (result != null) onChanged(result);
                },
              ),
            ],
          );
        },
      );
}

class _ProductSelection extends StatefulWidget {
  const _ProductSelection({required this.products, required this.selected});
  final List<Product> products;
  final List<String> selected;
  @override
  State<_ProductSelection> createState() => _ProductSelectionState();
}

class _ProductSelectionState extends State<_ProductSelection> {
  late final _selected = widget.selected.toSet();
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final products = widget.products
        .where((p) => p.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Link products · ${_selected.length}/5',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    child: const Text('Done'),
                  ),
                ],
              ),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search your products',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: products.isEmpty
                    ? const Center(child: Text('No published products match.'))
                    : ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final p = products[index];
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _selected.contains(p.id),
                            title: Text(
                              p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text('R${p.price.toStringAsFixed(2)}'),
                            onChanged: (checked) {
                              if (checked == true && _selected.length >= 5) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Choose up to five products.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                checked == true
                                    ? _selected.add(p.id)
                                    : _selected.remove(p.id);
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
