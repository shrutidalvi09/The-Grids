import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_providers.dart';
import '../../tower/data/tower_repository.dart';
import '../../tower/domain/tower_models.dart';
import '../../tower/presentation/tower_labels.dart';
import '../../tower/presentation/tower_providers.dart';
import '../data/gate_repository.dart';
import '../domain/gate_models.dart';
import 'gate_labels.dart';
import 'gate_providers.dart';

/// The gate: type a guest pass / daily-help code, or scan a guest's QR.
class PassCodeCard extends ConsumerStatefulWidget {
  const PassCodeCard({super.key});

  @override
  ConsumerState<PassCodeCard> createState() => _PassCodeCardState();
}

class _PassCodeCardState extends ConsumerState<PassCodeCard> {
  final _code = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check(String code) async {
    final l10n = context.l10n;
    final trimmed = code.trim();
    if (trimmed.length < 5) {
      setState(() => _error = l10n.passCodeHint);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final PassCheck result;
    try {
      result = await ref.read(gateRepositoryProvider).verifyPass(trimmed);
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = describeError(l10n, e);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _checking = false);
    _code.clear();
    FocusScope.of(context).unfocus();
    await showPassResult(context, ref, result);
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const ScanPassPage(), fullscreenDialog: true),
    );
    if (code != null && mounted) await _check(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.verifyPassTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.verifyPassHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              textInputAction: TextInputAction.done,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 6),
              decoration: InputDecoration(
                labelText: l10n.passCodeField,
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: l10n.scanQr,
                  onPressed: _checking ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ),
              onSubmitted: _check,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _checking ? null : () => _check(_code.text),
              icon: _checking
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_user_rounded),
              label: Text(l10n.verifyPass),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who the code belongs to, and the one action that makes sense: let the
/// guest in, or mark the helper in / out.
Future<void> showPassResult(BuildContext context, WidgetRef ref, PassCheck result) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);

  Future<void> act(BuildContext sheet, Future<void> Function() action, String done) async {
    Navigator.pop(sheet);
    try {
      await action();
      ref
        ..invalidate(visitorsProvider)
        ..invalidate(dailyHelpProvider)
        ..invalidate(homeProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (result) {
            GuestPass(:final visitor) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(label: l10n.validPass, tone: StatusTone.success)),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(visitorIcon(visitor.type), size: 36),
                    title: Text(visitor.name, style: theme.textTheme.titleLarge),
                    subtitle: Text([?visitor.purpose, ?visitor.flatLabel].join(' · ')),
                  ),
                  if (visitor.vehicleNumber != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.directions_car_rounded),
                      title: Text(l10n.guestVehicle(visitor.vehicleNumber!)),
                    ),
                  if (visitor.expectedAt != null)
                    Text(l10n.visitorExpectedAt(formatTime(sheet, visitor.expectedAt!))),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => act(
                      sheet,
                      () => ref.read(towerRepositoryProvider).setVisitorStatus(visitor.id, GateStatus.checkedIn),
                      l10n.visitorLetIn(visitor.name),
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(l10n.letIn),
                  ),
                ],
              ),
            StaffPass() => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: AlignmentDirectional.centerStart, child: StatusChip(label: l10n.dailyHelpTitle, tone: StatusTone.info)),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: PersonAvatar(name: result.name),
                    title: Text(result.name, style: theme.textTheme.titleLarge),
                    subtitle: Text([helpKindLabel(l10n, result.kind), ...result.flatLabels].join(' · ')),
                    trailing: result.phone == null
                        ? null
                        : IconButton(
                            tooltip: l10n.callPerson(result.name),
                            onPressed: () => callPhone(sheet, result.phone!),
                            icon: const Icon(Icons.call_rounded),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => act(
                      sheet,
                      () => ref.read(gateRepositoryProvider).markAttendance(result.id),
                      result.inside ? l10n.staffMarkedOut(result.name) : l10n.staffMarkedIn(result.name),
                    ),
                    icon: Icon(result.inside ? Icons.logout_rounded : Icons.login_rounded),
                    label: Text(result.inside ? l10n.markOut : l10n.markIn),
                  ),
                ],
              ),
          },
        ),
      );
    },
  );
}

/// Full-screen camera that returns the first Grids pass it sees.
class ScanPassPage extends StatefulWidget {
  const ScanPassPage({super.key});

  @override
  State<ScanPassPage> createState() => _ScanPassPageState();
}

class _ScanPassPageState extends State<ScanPassPage> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && RegExp(r'^grids:(pass|staff):\d{5,6}$', caseSensitive: false).hasMatch(value)) {
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(l10n.scanQr)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(l10n.cameraUnavailable, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(l10n.scanQrHint, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}
