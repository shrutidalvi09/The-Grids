import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/tower_models.dart';
import 'tower_providers.dart';
import 'widgets/tower_tiles.dart';

class NeighboursPage extends ConsumerStatefulWidget {
  const NeighboursPage({super.key});

  @override
  ConsumerState<NeighboursPage> createState() => _NeighboursPageState();
}

class _NeighboursPageState extends ConsumerState<NeighboursPage> {
  String _query = '';

  bool _matches(NeighbourFlat flat) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return flat.number.contains(q) || flat.residents.any((r) => r.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GridsPage(
      title: l10n.neighboursTitle,
      showMenu: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: TextField(
              decoration: InputDecoration(hintText: l10n.searchNeighboursHint, prefixIcon: const Icon(Icons.search_rounded)),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(neighboursProvider),
              onRetry: () => ref.invalidate(neighboursProvider),
              data: (towers) {
                final sections = [
                  for (final t in towers)
                    if (t.flats.where(_matches).toList() case final flats when flats.isNotEmpty) (t.towerName, flats),
                ];
                if (sections.isEmpty) return EmptyState(icon: Icons.diversity_3_rounded, title: l10n.noNeighbours);
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final (tower, flats) in sections) ...[
                      SectionHeader(title: tower, icon: Icons.apartment_rounded),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(children: [for (final f in flats) NeighbourTile(towerName: tower, flat: f)]),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
