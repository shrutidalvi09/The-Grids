import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../domain/facility_models.dart';
import '../facility_labels.dart';

/// Facility row with live status. Residents get "Book"; admins get "Edit".
class FacilityTile extends StatelessWidget {
  const FacilityTile({super.key, required this.facility, required this.isAdmin});

  final Facility facility;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = facility;
    return ListTile(
      leading: const Icon(Icons.meeting_room_rounded),
      title: Row(
        children: [
          Flexible(child: Text(f.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          facilityStatusChip(l10n, f.status),
        ],
      ),
      subtitle: Text(facilityStatusText(context, f.status)),
      trailing: isAdmin
          ? IconButton(
              tooltip: l10n.editFacility,
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => context.go(AppRoutes.facilityForm, extra: f),
            )
          : FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => context.go(AppRoutes.bookFacility(f.id)),
              child: Text(l10n.book),
            ),
    );
  }
}
