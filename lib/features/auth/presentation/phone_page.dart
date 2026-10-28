import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_providers.dart';
import 'sign_in_flow.dart';
import 'widgets/auth_layout.dart';

/// Step 3: mobile number → send code.
class PhonePage extends ConsumerStatefulWidget {
  const PhonePage({super.key});

  @override
  ConsumerState<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends ConsumerState<PhonePage> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: ref.read(signInFlowProvider).phone);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final flow = ref.read(signInFlowProvider);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(authRepositoryProvider).requestOtp(
            phone: _phone.text,
            societyId: flow.society!.id,
            role: flow.role!,
          );
      ref.read(signInFlowProvider.notifier).codeSent(_phone.text, challenge);
      if (mounted) await context.push(AppRoutes.signInOtp);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(signInFlowProvider).role;

    return AuthLayout(
      children: [
        AuthHeading(
          subtitle: role?.loginLabel(l10n).toUpperCase(),
          body: l10n.phonePrompt,
        ),
        const SizedBox(height: AppSpacing.xl),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _phone,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: l10n.mobileNumberLabel,
              prefixText: '+91 ',
              hintText: '98765 43210',
            ),
            validator: Validators(l10n).indianMobile,
            onFieldSubmitted: (_) => _sendCode(),
          ),
        ),
        AuthError(_error),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(label: l10n.sendCode, isLoading: _sending, onPressed: _sendCode),
      ],
    );
  }
}
