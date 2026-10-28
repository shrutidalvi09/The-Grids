import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/photo_field.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/profile_repository.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _deleting = false;

  Future<void> _logout() async {
    final l10n = context.l10n;
    final ok = await confirmAction(context, title: l10n.logoutConfirm, confirmLabel: l10n.drawerLogout);
    if (ok) await ref.read(sessionControllerProvider.notifier).signOut();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: l10n.deleteAccountConfirmTitle,
      message: l10n.deleteAccountConfirmBody,
      confirmLabel: l10n.deleteAccount,
      destructive: true,
    );
    if (!ok) return;
    setState(() => _deleting = true);
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
      await ref.read(sessionControllerProvider.notifier).signOut();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;
    return GridsPage(
      title: l10n.accountOptionsTitle,
      showMenu: false,
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          ListTileCard(
            leading: const Icon(Icons.edit_rounded),
            title: l10n.editProfile,
            onTap: () => context.push(AppRoutes.editProfile),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTileCard(
            leading: const Icon(Icons.logout_rounded),
            title: l10n.drawerLogout,
            onTap: _logout,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.dangerZone, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: error)),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.deleteAccountHint, style: TextStyle(color: GridsColors.of(context).slate)),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: error,
              side: BorderSide(color: error),
              minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
            ),
            onPressed: _deleting ? null : _delete,
            icon: _deleting
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_forever_rounded),
            label: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
  }
}

/// Name, email and photo. The mobile number is the login and can't be edited here.
class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    return GridsPage(
      title: context.l10n.editProfile,
      showMenu: false,
      showNotifications: false,
      body: session == null ? const SizedBox.shrink() : _EditProfileForm(session: session),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.session});

  final AppSession session;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.session.displayName);
  late final _emailCtrl = TextEditingController(text: widget.session.email);
  late String? _photoPath = widget.session.photoPath;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final email = _emailCtrl.text.trim();
    try {
      final updated = await ref.read(profileRepositoryProvider).updateProfile(
            name: _name.text.trim(),
            email: email.isEmpty ? null : email,
            clearEmail: email.isEmpty,
            photoPath: _photoPath,
            clearPhoto: _photoPath == null,
          );
      ref.read(sessionControllerProvider.notifier).updated(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    return Form(
      key: _form,
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          PhotoField(path: _photoPath, onChanged: (path) => setState(() => _photoPath = path)),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.nameField),
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _emailCtrl,
            decoration: InputDecoration(labelText: l10n.emailOptionalField),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (v) => (v == null || v.trim().isEmpty || _email.hasMatch(v.trim())) ? null : l10n.validationEmail,
          ),
          const SizedBox(height: AppSpacing.md),
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.mobileNumberLabel, helperText: l10n.phoneIsLoginHint),
            child: Text(formatPhone(widget.session.phone)),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: l10n.save, isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
