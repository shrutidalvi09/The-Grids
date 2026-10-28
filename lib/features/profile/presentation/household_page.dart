import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';
import 'profile_providers.dart';

enum _MemberAction { edit, remove }

/// People living in the flat: name, relation and an optional mobile number.
class HouseholdPage extends ConsumerWidget {
  const HouseholdPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.householdTitle,
      showMenu: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showHouseholdForm(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l10n.addMember),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(householdProvider.future),
        child: AsyncValueView(
          value: ref.watch(householdProvider),
          onRetry: () => ref.invalidate(householdProvider),
          isEmpty: (list) => list.isEmpty,
          empty: EmptyState(icon: Icons.family_restroom_rounded, title: l10n.noHousehold, message: l10n.noHouseholdHint),
          data: (list) => ListView.builder(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
            itemCount: list.length,
            itemBuilder: (context, i) => _MemberCard(member: list[i]),
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.member});

  final HouseholdMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final m = member;

    Future<void> remove() async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await confirmAction(
        context,
        title: l10n.removeMemberConfirm(m.name),
        confirmLabel: l10n.remove,
        destructive: true,
      );
      if (!ok) return;
      try {
        await ref.read(profileRepositoryProvider).removeHouseholdMember(m.id);
        ref.invalidate(householdProvider);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        leading: PersonAvatar(name: m.name, photoPath: m.photoPath),
        title: Text(m.name),
        subtitle: Text([m.relation, if (m.phone != null) formatPhone(m.phone!)].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.phone != null)
              IconButton(
                tooltip: l10n.callPerson(m.name),
                onPressed: () => callPhone(context, m.phone!),
                icon: const Icon(Icons.call_rounded),
              ),
            PopupMenuButton<_MemberAction>(
              tooltip: l10n.memberActions,
              onSelected: (action) => action == _MemberAction.edit ? showHouseholdForm(context, ref, member: m) : remove(),
              itemBuilder: (_) => [
                PopupMenuItem(value: _MemberAction.edit, child: Text(l10n.edit)),
                PopupMenuItem(value: _MemberAction.remove, child: Text(l10n.remove)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add (or edit) a household member in a bottom sheet.
Future<void> showHouseholdForm(BuildContext context, WidgetRef ref, {HouseholdMember? member}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final validators = Validators(l10n);
  final name = TextEditingController(text: member?.name);
  final relation = TextEditingController(text: member?.relation);
  final phone = TextEditingController(text: member?.phone?.replaceFirst('+91', ''));

  final saved = await BottomSheetForm.show(
    context,
    title: member == null ? l10n.addMember : l10n.editMember,
    submitLabel: member == null ? l10n.addMember : l10n.save,
    fields: [
      TextFormField(
        controller: name,
        decoration: InputDecoration(labelText: l10n.nameField),
        textCapitalization: TextCapitalization.words,
        maxLength: 80,
        validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
      ),
      TextFormField(
        controller: relation,
        decoration: InputDecoration(labelText: l10n.relationField, hintText: l10n.relationHint),
        textCapitalization: TextCapitalization.words,
        maxLength: 30,
        validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
      ),
      TextFormField(
        controller: phone,
        decoration: InputDecoration(labelText: l10n.mobileOptionalField, prefixText: '+91 '),
        keyboardType: TextInputType.phone,
        validator: (v) => v == null || v.trim().isEmpty ? null : validators.indianMobile(v),
      ),
    ],
    onSubmit: () {
      final input = HouseholdInput(
        name: name.text.trim(),
        relation: relation.text.trim(),
        phone: phone.text.trim().isEmpty ? null : Validators.normalizeIndianMobile(phone.text),
        photoPath: member?.photoPath,
      );
      final repo = ref.read(profileRepositoryProvider);
      return member == null ? repo.addHouseholdMember(input) : repo.updateHouseholdMember(member.id, input);
    },
  );
  name.dispose();
  relation.dispose();
  phone.dispose();
  if (saved == true) {
    ref.invalidate(householdProvider);
    messenger.showSnackBar(SnackBar(content: Text(member == null ? l10n.memberAdded : l10n.memberSaved)));
  }
}
