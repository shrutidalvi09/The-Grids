import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../data/community_repository.dart';
import '../../domain/community_models.dart';
import '../community_providers.dart';

/// One poll: pick-and-vote while open, then result bars with counts.
class PollCard extends ConsumerStatefulWidget {
  const PollCard({super.key, required this.poll});

  final Poll poll;

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

enum _AdminAction { close, delete }

class _PollCardState extends ConsumerState<PollCard> {
  String? _selected;
  bool _voting = false;

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _vote() async {
    final l10n = context.l10n;
    final optionId = _selected;
    if (optionId == null) return;
    setState(() => _voting = true);
    try {
      await ref.read(communityRepositoryProvider).vote(widget.poll.id, optionId);
      if (mounted) _snack(l10n.voteRecorded);
    } catch (e) {
      if (mounted) _snack(describeError(l10n, e));
    } finally {
      // Refresh either way: a closed poll or an earlier vote changes what we show.
      ref.invalidate(pollsProvider);
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _admin(_AdminAction action) async {
    final l10n = context.l10n;
    final repo = ref.read(communityRepositoryProvider);
    final ok = await confirmAction(
      context,
      title: action == _AdminAction.close ? l10n.closePoll : l10n.deletePoll,
      message: action == _AdminAction.close ? l10n.closePollConfirm : l10n.deletePollConfirm,
      confirmLabel: action == _AdminAction.close ? l10n.closePoll : l10n.delete,
      destructive: action == _AdminAction.delete,
    );
    if (!ok) return;
    try {
      if (action == _AdminAction.close) {
        await repo.closePoll(widget.poll.id);
      } else {
        await repo.deletePoll(widget.poll.id);
      }
      ref.invalidate(pollsProvider);
      if (mounted) _snack(action == _AdminAction.close ? l10n.pollClosedDone : l10n.pollDeleted);
    } catch (e) {
      if (mounted) _snack(describeError(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final poll = widget.poll;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    final status = [
      l10n.totalVotes(poll.totalVotes),
      if (!poll.isOpen)
        l10n.pollClosed
      else if (poll.closesAt != null)
        l10n.pollClosesOn(formatDayMonth(context, poll.closesAt!)),
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(poll.question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(status, style: TextStyle(color: grids.slate)),
                      ],
                    ),
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<_AdminAction>(
                    tooltip: l10n.pollActions,
                    onSelected: _admin,
                    itemBuilder: (_) => [
                      if (poll.isOpen) PopupMenuItem(value: _AdminAction.close, child: Text(l10n.closePoll)),
                      PopupMenuItem(value: _AdminAction.delete, child: Text(l10n.deletePoll)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: poll.resultsVisible ? _Results(poll: poll) : _ballot(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ballot(AppLocalizations l10n) {
    final poll = widget.poll;
    if (!poll.isOpen) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<String>(
          groupValue: _selected,
          onChanged: (value) => _voting ? null : setState(() => _selected = value),
          child: Column(
            children: [
              for (final option in poll.options)
                RadioListTile<String>(
                  value: option.id,
                  title: Text(option.label),
                  contentPadding: EdgeInsets.zero,
                  dense: false,
                ),
            ],
          ),
        ),
        Text(l10n.resultsAfterVoting, style: TextStyle(color: GridsColors.of(context).slate)),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: l10n.vote,
          icon: Icons.how_to_vote_rounded,
          isLoading: _voting,
          onPressed: _selected == null || _voting ? null : _vote,
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.poll});

  final Poll poll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final total = poll.totalVotes;
    final mine = poll.myOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in poll.options)
          _ResultBar(option: option, total: total, isMine: option.id == poll.myOptionId),
        if (mine != null) ...[
          const Divider(height: AppSpacing.xl),
          Text.rich(
            TextSpan(
              text: l10n.youVotedForLabel,
              children: [
                TextSpan(
                  text: mine.label,
                  style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({required this.option, required this.total, required this.isMine});

  final PollOption option;
  final int total;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final grids = GridsColors.of(context);
    final votes = option.votes ?? 0;
    final percent = total == 0 ? 0 : (votes * 100 / total).round();
    final countText = l10n.voteCount(votes, percent);
    return Semantics(
      container: true,
      label: '${option.label}, $countText${isMine ? ', ${l10n.yourVote}' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: isMine ? FontWeight.w700 : null),
                  ),
                ),
                if (isMine) Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(AppRadii.pill),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : votes / total,
                      minHeight: 10,
                      color: theme.colorScheme.primary,
                      backgroundColor: grids.slate.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 112,
                  child: Text(countText, textAlign: TextAlign.end, style: TextStyle(color: grids.slate)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
