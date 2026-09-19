import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/errors/forma_error.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';
import 'package:forma/design_system/components/empty_state.dart';
import 'package:forma/design_system/components/primary_button.dart';
import 'package:forma/design_system/haptics/app_haptics.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';
import 'package:forma/features/capture/capture_screen.dart';
import 'package:forma/features/library/library_view_model.dart';
import 'package:forma/features/library/widgets/scan_card.dart';
import 'package:forma/features/unsupported_device/unsupported_device_screen.dart';
import 'package:forma/features/viewer/model_viewer_screen.dart';

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
          Strings.libraryTitle,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        // Visible build stamp (CI-injected) so a device test can confirm
        // which build is installed without attaching a cable.
        actions: [
          if (Strings.buildStamp.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: Text(
                  'v${Strings.buildStamp}',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: scans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error,
          title: Strings.loadFailedTitle,
          subtitle: Strings.loadFailedSubtitle,
          ctaLabel: Strings.retry,
          onCta: () => ref.invalidate(scanListProvider),
        ),
        // The scan entry point is a labelled button pinned to the bottom, not
        // a floating icon: the one action this app exists for should name
        // itself and sit exactly where a thumb already rests
        // (user request 2026-09-18).
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.view_in_ar,
                title: Strings.emptyTitle,
                subtitle: Strings.emptySubtitle,
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
                itemBuilder: (context, index) => ScanCard(
                  scan: items[index],
                  onTap: () => _openScan(context, items[index]),
                  onDelete: () => _confirmDelete(context, ref, items[index]),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: PrimaryButton(
          label: Strings.startScan,
          onPressed: () => _startScan(context, ref),
        ),
      ),
    );
  }

  /// Confirms, then deletes a scan and everything it owns on disk.
  ///
  /// Deletion is irreversible and a scan costs minutes to make, so it is
  /// never one tap: the dialog names the scan so a mis-tap on the wrong card
  /// is caught while it is still undoable by walking away.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Scan scan,
  ) async {
    AppHaptics.stateChange();
    final colors = FormaColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.bgElevated,
        title: Text(
          Strings.deleteScanTitle,
          style: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          Strings.deleteScanBody(scan.name),
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              Strings.keep,
              style: AppTypography.headline.copyWith(color: colors.accent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              Strings.deleteScan,
              style: AppTypography.headline.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    // Resolved before the await: the screen's context is not guaranteed to
    // still be mounted once the deletion finishes.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(scanDeleterProvider).delete(scan);
      if (!context.mounted) {
        return;
      }
      AppHaptics.success();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(Strings.scanDeleted),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } on FormaError catch (e) {
      debugPrint('[forma] delete failed: ${e.debugMessage}');
      AppHaptics.error();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(Strings.deleteFailed),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Opens a scan's 360° model viewer, or says honestly why it cannot.
  ///
  /// A scan whose model is not written yet must not open a black screen, so
  /// the card only routes to the viewer once the model exists (device-test
  /// finding 2026-09-18: "model is created in the app but it is not
  /// viewable" — there was no viewer at all).
  Future<void> _openScan(BuildContext context, Scan scan) async {
    if (scan.modelPath == null || scan.status != ScanStatus.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(Strings.scanStillBuilding),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModelViewerScreen(scan: scan),
      ),
    );
  }

  Future<void> _startScan(BuildContext context, WidgetRef ref) async {
    final supported = await ref.read(scanSupportProvider.future);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => supported
            ? const CaptureScreen()
            : const UnsupportedDeviceScreen(),
      ),
    );
  }
}
