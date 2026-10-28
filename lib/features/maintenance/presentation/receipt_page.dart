import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/receipt_files.dart';
import '../domain/money_models.dart';
import 'money_providers.dart';
import 'widgets/money_widgets.dart';

/// A payment's receipt, with the server-generated PDF to download or share.
class ReceiptPage extends ConsumerWidget {
  const ReceiptPage({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridsPage(
      title: context.l10n.receiptTitle,
      showMenu: false,
      showNotifications: false,
      body: AsyncValueView(
        value: ref.watch(paymentProvider(paymentId)),
        onRetry: () => ref.invalidate(paymentProvider(paymentId)),
        data: (payment) => _ReceiptView(payment: payment),
      ),
    );
  }
}

class _ReceiptView extends ConsumerStatefulWidget {
  const _ReceiptView({required this.payment});

  final Payment payment;

  @override
  ConsumerState<_ReceiptView> createState() => _ReceiptViewState();
}

class _ReceiptViewState extends ConsumerState<_ReceiptView> {
  bool _downloading = false;
  bool _sharing = false;

  Future<void> _run(Future<void> Function(ReceiptFiles files) action, void Function(bool) busy) async {
    final l10n = context.l10n;
    setState(() => busy(true));
    try {
      await action(ref.read(receiptFilesProvider));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => busy(false));
    }
  }

  Future<void> _download() => _run((files) async {
        final opened = await files.download(widget.payment.id);
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.noPdfViewer)));
        }
      }, (v) => _downloading = v);

  Future<void> _share() {
    final p = widget.payment;
    final message = context.l10n.receiptShareText(p.receiptNo ?? '', p.societyName);
    return _run((files) => files.share(p.id, message: message), (v) => _sharing = v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final p = widget.payment;
    final paid = p.status == PaymentStatus.succeeded;
    final towards = '${p.dueType == DueType.rent ? l10n.navRent : l10n.navMaintenance} · '
        '${formatPeriod(context, p.periodMonth)}';

    final rows = <(String, String)>[
      if (p.receiptNo != null) (l10n.receiptNoLabel, p.receiptNo!),
      if (p.paidAt != null) (l10n.paidOnLabel, '${formatDate(context, p.paidAt!)}, ${formatTime(context, p.paidAt!)}'),
      (l10n.amountLabel, formatPaise(p.amountPaise)),
      (l10n.paymentModeLabel, methodLabel(l10n, p.method)),
      (l10n.memberNameLabel, p.payerName),
      if (p.flatLabel != null) (l10n.flatLabelField, p.flatLabel!),
      (l10n.societyLabel, p.societyName),
      (l10n.towardsLabel, towards),
      if (p.transactionId != null) (l10n.transactionIdLabel, p.transactionId!),
    ];

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                paid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                size: 56,
                color: paid ? grids.success : grids.warning,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                paid ? l10n.paymentSuccessful : l10n.paymentPendingTitle,
                style: theme.textTheme.titleLarge,
              ),
              Text(
                formatPaise(p.amountPaise),
                style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                    child: MergeSemantics(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: Text(label, style: TextStyle(color: grids.slate))),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 3,
                            child: Text(value, textAlign: TextAlign.end, style: theme.textTheme.bodyLarge),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (p.breakdown.isNotEmpty) BreakdownCard(items: p.breakdown),
        if (paid) ...[
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.downloadPdf,
            icon: Icons.download_rounded,
            isLoading: _downloading,
            onPressed: _downloading || _sharing ? null : _download,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(AppSpacing.minTapTarget)),
            onPressed: _downloading || _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_rounded),
            label: Text(l10n.share),
          ),
        ],
      ],
    );
  }
}
