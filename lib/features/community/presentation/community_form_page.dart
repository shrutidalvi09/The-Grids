import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/photo_field.dart';
import '../../../core/widgets/widgets.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_providers.dart';

/// Admin: create a club, or edit [communityId]'s name, photo and members.
class CommunityFormPage extends ConsumerWidget {
  const CommunityFormPage({super.key, this.communityId});

  final String? communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = communityId;
    final candidates = ref.watch(communityCandidatesProvider);
    final existing = id == null ? null : ref.watch(communityProvider(id));

    return GridsPage(
      title: id == null ? l10n.newCommunity : l10n.editCommunity,
      showMenu: false,
      showNotifications: false,
      body: AsyncValueView<(List<CommunityMember>, CommunityDetail?)>(
        value: _combine(candidates, existing),
        onRetry: () {
          ref.invalidate(communityCandidatesProvider);
          if (id != null) ref.invalidate(communityProvider(id));
        },
        data: (data) => _CommunityForm(candidates: data.$1, existing: data.$2),
      ),
    );
  }

  /// Both the people to pick from and (when editing) the current club.
  static AsyncValue<(List<CommunityMember>, CommunityDetail?)> _combine(
    AsyncValue<List<CommunityMember>> candidates,
    AsyncValue<CommunityDetail>? existing,
  ) {
    if (candidates case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
    if (existing case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
    final people = candidates.value;
    if (people == null || (existing != null && !existing.hasValue)) return const AsyncLoading();
    return AsyncData((people, existing?.value));
  }
}

class _CommunityForm extends ConsumerStatefulWidget {
  const _CommunityForm({required this.candidates, this.existing});

  final List<CommunityMember> candidates;
  final CommunityDetail? existing;

  @override
  ConsumerState<_CommunityForm> createState() => _CommunityFormState();
}

class _CommunityFormState extends ConsumerState<_CommunityForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.community.name);
  late final _description = TextEditingController(text: widget.existing?.community.description);
  final _search = TextEditingController();
  late String? _photoPath = widget.existing?.community.photoPath;
  late final Set<String> _selected = {...?widget.existing?.members.map((m) => m.userId)};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = CommunityInput(
      name: _name.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      photoPath: _photoPath,
      memberIds: _selected.toList(),
    );
    final repo = ref.read(communityRepositoryProvider);
    final existing = widget.existing;
    try {
      final saved = existing == null
          ? await repo.createCommunity(input)
          : await repo.updateCommunity(existing.community.id, input);
      ref
        ..invalidate(communitiesProvider)
        ..invalidate(communityProvider(saved.community.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? l10n.communityCreated : l10n.communitySaved)),
      );
      if (existing == null) {
        context.pushReplacement(AppRoutes.communityClub(saved.community.id));
      } else {
        context.pop();
      }
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
    final slate = GridsColors.of(context).slate;
    final query = _search.text.trim().toLowerCase();
    final visible = widget.candidates
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(query) || (c.flatLabel ?? '').toLowerCase().contains(query))
        .toList();

    return Form(
      key: _form,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            sliver: SliverList.list(
              children: [
                PhotoField(path: _photoPath, onChanged: (path) => setState(() => _photoPath = path)),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.communityNameLabel),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 60,
                  validator: (v) => validators.required(v) ?? (v!.trim().length < 2 ? l10n.validationTooShort : null),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _description,
                  decoration: InputDecoration(labelText: l10n.fieldDescription, alignLabelWithHint: true),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: Text(l10n.addMembers, style: Theme.of(context).textTheme.titleMedium)),
                    Text(l10n.membersSelected(_selected.length), style: TextStyle(color: slate)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: l10n.searchMembersHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final person = visible[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: CheckboxListTile(
                    value: _selected.contains(person.userId),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(person.name),
                    secondary: person.flatLabel == null ? null : Text(person.flatLabel!, style: TextStyle(color: slate)),
                    onChanged: (checked) => setState(
                      () => checked! ? _selected.add(person.userId) : _selected.remove(person.userId),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
            sliver: SliverList.list(
              children: [
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: AppSpacing.md),
                ],
                PrimaryButton(
                  label: widget.existing == null ? l10n.create : l10n.save,
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
