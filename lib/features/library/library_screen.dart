import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/design_system/components/empty_state.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/features/library/widgets/scan_card.dart';

/// Home screen: the scan library grid (design.md §4.3).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scans = ref.watch(scanListProvider);
    final colors = FormaColors.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Forma',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: scans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error,
          title: 'Something went wrong',
          subtitle: 'Could not load your library.',
          ctaLabel: 'Try again',
          onCta: () => ref.invalidate(scanListProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.view_in_ar,
                title: 'Nothing here yet',
                subtitle: 'Scan your first object to turn it into 3D.',
                ctaLabel: 'Start scanning',
                onCta: () => _startScan(context, ref),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    ScanCard(scan: items[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => _startScan(context, ref),
        child: const Icon(Icons.filter_center_focus, size: 28),
      ),
    );
  }

  Future<void> _startScan(BuildContext context, WidgetRef ref) async {
    final bridge = ref.read(nativeBridgeProvider);
    final repository = ref.read(scanRepositoryProvider);
    final id = await bridge.startCapture();
    await bridge.finishCapture(id);
    await bridge.startReconstruction(id);
    await repository.save(
      Scan(
        id: id,
        name: 'Scan ${DateTime.now().hour}:${DateTime.now().minute}',
        createdAt: DateTime.now(),
        status: ScanStatus.ready,
        modelPath: '/fake/scans/$id/model.usdz',
        bytes: 1_204_000,
      ),
    );
  }
}
