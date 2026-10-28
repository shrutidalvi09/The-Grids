import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_providers.dart';
import '../domain/auth_models.dart';
import 'session_controller.dart';
import 'sign_in_flow.dart';
import 'widgets/auth_layout.dart';
import 'widgets/otp_input.dart';

/// Step 4: enter the code. On success the router moves to Home.
class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _code = TextEditingController();
  Timer? _timer;
  int _resendIn = 0;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _startCountdown(ref.read(signInFlowProvider).challenge);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(OtpChallenge? challenge) {
    _timer?.cancel();
    _resendIn = challenge?.resendIn.inSeconds ?? 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final challenge = ref.read(signInFlowProvider).challenge;
    if (_code.text.length != 6 || challenge == null || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .verifyOtp(challengeId: challenge.challengeId, code: _code.text);
      ref.read(sessionControllerProvider.notifier).signedIn(session);
      ref.read(signInFlowProvider.notifier).reset();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(context.l10n, e);
        _code.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    final flow = ref.read(signInFlowProvider);
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestOtp(phone: flow.phone!, societyId: flow.society!.id, role: flow.role!);
      ref.read(signInFlowProvider.notifier).codeSent(flow.phone!, challenge);
      _code.clear();
      _startCountdown(challenge);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final flow = ref.watch(signInFlowProvider);
    final devCode = ref.watch(appConfigProvider).isDev ? flow.challenge?.devCode : null;
    final phone = flow.phone ?? '';
    final displayPhone = phone.length == 10 ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}' : '+91 $phone';

    return AuthLayout(
      children: [
        AuthHeading(
          subtitle: flow.role?.loginLabel(l10n).toUpperCase(),
          body: l10n.otpPrompt(displayPhone),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (devCode != null) ...[
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.developer_mode_rounded),
              title: Text(l10n.devOtpBanner(devCode)),
              trailing: TextButton(
                onPressed: () {
                  _code.text = devCode;
                  _verify();
                },
                child: Text(l10n.useCode),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        OtpInput(
          controller: _code,
          semanticLabel: l10n.verificationCodeLabel,
          hasError: _error != null,
          onCompleted: (_) => _verify(),
        ),
        AuthError(_error),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: Text(l10n.didNotReceiveCode)),
            if (_resendIn > 0)
              Text(
                l10n.resendIn(_resendIn),
                style: TextStyle(color: theme.colorScheme.error),
              )
            else
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(l10n.resendCode),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: l10n.login,
          isLoading: _verifying,
          onPressed: _code.text.length == 6 ? _verify : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: () => context.pop(), child: Text(l10n.changeNumber)),
      ],
    );
  }
}
