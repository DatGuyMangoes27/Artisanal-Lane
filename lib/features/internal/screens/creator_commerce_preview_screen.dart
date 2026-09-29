import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../concepts/creator_commerce/creator_commerce_mockup_app.dart';
import '../providers/creator_commerce_preview_provider.dart';

class CreatorCommercePreviewScreen extends ConsumerWidget {
  const CreatorCommercePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(creatorCommerceCatalogProvider);

    return catalog.when(
      data: (value) => CreatorCommerceMockupHost(catalog: value),
      loading: () => const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: AppTheme.terracotta,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'The live catalogue could not be loaded.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Retry when the device is online. The preview will use demo content only when an individual live source is unavailable.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(creatorCommerceCatalogProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
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
