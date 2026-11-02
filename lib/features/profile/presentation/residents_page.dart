import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone_call.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';
import 'profile_providers.dart';
import 'widgets/flat_picker.dart';

/// Admin: everyone registered in the society, invite new people by mobile
/// number, remove access.
class ResidentsPage extends ConsumerStatefulWidget {
  const ResidentsPage({super.key});

  @override
  ConsumerState<ResidentsPage> createState() => _ResidentsPageState();
}

class _ResidentsPageState extends ConsumerState<ResidentsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() => ref
    ..invalidate(membersProvider)
    ..invalidate(flatOptionsProvider);

  Future<void> _remove(Member m) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: l10n.removeMemberConfirm(m.name),
      message: l10n.removeResidentBody,
      confirmLabel: l10n.remove,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(profileRepositoryProvider).removeMember(m.membershipId);
      _refresh();
      messenger.showSnackBar(SnackBar(content: Text(l10n.residentRemoved(m.name))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _search.text.trim().toLowerCase();
    return GridsPage(
      title: l10n.residentsTitle,
      showMenu: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await showInviteForm(context, ref) == true) _refresh();
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l10n.inviteResident),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(membersProvider.future),
        child: AsyncValueView(
          value: ref.watch(membersProvider),
          onRetry: () => ref.invalidate(membersProvider),
          data: (all) {
            final members = all
                .where((m) =>
                    query.isEmpty ||
                    m.name.toLowerCase().contains(query) ||
                    (m.flatLabel ?? '').toLowerCase().contains(query) ||
                    m.phone.contains(query))
                .toList();
            final groups = [
              (l10n.roleAdmin, members.where((m) => m.role == UserRole.admin).toList()),
              (l10n.roleOwner, members.where((m) => m.role == UserRole.owner).toList()),
              (l10n.roleTenant, members.where((m) => m.role == UserRole.tenant).toList()),
              (l10n.roleGuard, members.where((m) => m.role == UserRole.guard).toList()),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(hintText: l10n.searchMembersHint, prefixIcon: const Icon(Icons.search_rounded)),
                  onChanged: (_) => setState(() {}),
                ),
                for (final (title, list) in groups)
                  if (list.isNotEmpty) ...[
                    SectionHeader(title: '$title (${list.length})', icon: Icons.people_alt_rounded),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [for (final m in list) _MemberTile(member: m, onRemove: () => _remove(m))],
                      ),
                    ),
                  ],
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(l10n.noMatches, textAlign: TextAlign.center),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _MemberAction { call, remove }

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onRemove});

  final Member member;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = member;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      leading: PersonAvatar(name: m.name),
      title: Text(m.name),
      subtitle: Text(
        [?m.flatLabel, formatPhone(m.phone)].join(' · '),
        style: TextStyle(color: GridsColors.of(context).slate),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.invited) StatusChip(label: l10n.invitedStatus, tone: StatusTone.warning),
          PopupMenuButton<_MemberAction>(
            tooltip: l10n.memberActions,
            onSelected: (a) => a == _MemberAction.call ? callPhone(context, m.phone) : onRemove(),
            itemBuilder: (_) => [
              PopupMenuItem(value: _MemberAction.call, child: Text(l10n.callPerson(m.name))),
              PopupMenuItem(value: _MemberAction.remove, child: Text(l10n.removeAccess)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Register a mobile number for a role (and flat). They then sign in with OTP.
Future<bool?> showInviteForm(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final validators = Validators(l10n);
  final name = TextEditingController();
  final phone = TextEditingController();
  var role = UserRole.owner;
  String? flatId;

  final saved = await BottomSheetForm.show(
    context,
    title: l10n.inviteResident,
    submitLabel: l10n.sendInvite,
    fields: [
      _RoleAndFlat(
        onRoleChanged: (r) => role = r,
        onFlatChanged: (id) => flatId = id,
      ),
      TextFormField(
        controller: name,
        decoration: InputDecoration(labelText: l10n.nameField),
        textCapitalization: TextCapitalization.words,
        maxLength: 80,
        validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
      ),
      TextFormField(
        controller: phone,
        decoration: InputDecoration(labelText: l10n.mobileNumberLabel, prefixText: '+91 ', helperText: l10n.inviteHint, helperMaxLines: 2),
        keyboardType: TextInputType.phone,
        validator: validators.indianMobile,
      ),
    ],
    onSubmit: () => ref.read(profileRepositoryProvider).invite(
          name: name.text.trim(),
          phone: Validators.normalizeIndianMobile(phone.text)!,
          role: role,
          flatId: role.isResident ? flatId : null,
        ),
  );
  if (saved == true) messenger.showSnackBar(SnackBar(content: Text(l10n.inviteSent(name.text.trim()))));
  return saved;
}

/// Role choice; the flat picker appears for owners and tenants.
class _RoleAndFlat extends StatefulWidget {
  const _RoleAndFlat({required this.onRoleChanged, required this.onFlatChanged});

  final ValueChanged<UserRole> onRoleChanged;
  final ValueChanged<String?> onFlatChanged;

  @override
  State<_RoleAndFlat> createState() => _RoleAndFlatState();
}

class _RoleAndFlatState extends State<_RoleAndFlat> {
  UserRole _role = UserRole.owner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<UserRole>(
          segments: [
            ButtonSegment(value: UserRole.owner, label: Text(l10n.roleOwner)),
            ButtonSegment(value: UserRole.tenant, label: Text(l10n.roleTenant)),
            ButtonSegment(value: UserRole.admin, label: Text(l10n.roleAdmin)),
            ButtonSegment(value: UserRole.guard, label: Text(l10n.roleGuardShort)),
          ],
          selected: {_role},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            setState(() => _role = s.single);
            widget.onRoleChanged(s.single);
          },
        ),
        if (_role.isResident) ...[
          const SizedBox(height: AppSpacing.lg),
          FlatPicker(onChanged: widget.onFlatChanged),
        ],
      ],
    );
  }
}
