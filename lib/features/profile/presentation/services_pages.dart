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
import '../../../core/utils/phone_call.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';
import 'profile_providers.dart';

/// Icon and translated name for the usual categories; others show as entered.
(IconData, String) serviceCategoryLook(AppLocalizations l10n, String category) =>
    switch (category.toLowerCase()) {
      'maid' => (Icons.cleaning_services_rounded, l10n.serviceMaid),
      'cook' => (Icons.soup_kitchen_rounded, l10n.serviceCook),
      'driver' => (Icons.drive_eta_rounded, l10n.serviceDriver),
      'laundry' => (Icons.local_laundry_service_rounded, l10n.serviceLaundry),
      'doctor' => (Icons.medical_services_rounded, l10n.serviceDoctor),
      'plumber' => (Icons.plumbing_rounded, l10n.servicePlumber),
      'electrician' || 'electrical' => (Icons.electrical_services_rounded, l10n.serviceElectrician),
      'gym' => (Icons.fitness_center_rounded, l10n.serviceGym),
      'newspaper' => (Icons.newspaper_rounded, l10n.serviceNewspaper),
      'milkman' => (Icons.local_drink_rounded, l10n.serviceMilkman),
      'carpenter' => (Icons.carpenter_rounded, l10n.serviceCarpenter),
      'babysitter' => (Icons.child_care_rounded, l10n.serviceBabysitter),
      _ => (Icons.handyman_rounded, category),
    };

/// Categories as a grid (Maid, Cook, Driver…).
class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    return GridsPage(
      title: l10n.servicesTitle,
      showMenu: false,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddService(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addService),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(servicesProvider.future),
        child: AsyncValueView(
          value: ref.watch(servicesProvider),
          onRetry: () => ref.invalidate(servicesProvider),
          isEmpty: (list) => list.isEmpty,
          empty: EmptyState(icon: Icons.handyman_rounded, title: l10n.noServices),
          data: (list) {
            final counts = <String, int>{};
            for (final s in list) {
              counts[s.category] = (counts[s.category] ?? 0) + 1;
            }
            final categories = counts.keys.toList();
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.3,
              ),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final category = categories[i];
                final (icon, label) = serviceCategoryLook(l10n, category);
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.go(AppRoutes.serviceCategory(category)),
                    child: Semantics(
                      button: true,
                      label: '$label, ${l10n.contactsCount(counts[category]!)}',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: AppSpacing.sm),
                          Text(label, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                          Text(
                            l10n.contactsCount(counts[category]!),
                            style: TextStyle(color: GridsColors.of(context).slate),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Contacts in one category, each with a call button.
class ServiceCategoryPage extends ConsumerWidget {
  const ServiceCategoryPage({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = ref.watch(currentSessionProvider)?.role == UserRole.admin;
    final (icon, label) = serviceCategoryLook(l10n, category);
    final slate = GridsColors.of(context).slate;

    Future<void> remove(ServiceProvider s) async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await confirmAction(context, title: l10n.removeServiceConfirm(s.name), confirmLabel: l10n.remove, destructive: true);
      if (!ok) return;
      try {
        await ref.read(profileRepositoryProvider).removeService(s.id);
        ref.invalidate(servicesProvider);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
      }
    }

    return GridsPage(
      title: label,
      showMenu: false,
      body: AsyncValueView(
        value: ref.watch(servicesProvider),
        onRetry: () => ref.invalidate(servicesProvider),
        data: (all) {
          final list = all.where((s) => s.category == category).toList();
          if (list.isEmpty) return EmptyState(icon: icon, title: l10n.noServices);
          return ListView.builder(
            padding: AppSpacing.pagePadding,
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
                  leading: PersonAvatar(name: s.name),
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      ?s.location,
                      if (s.rating != null) '★ ${s.rating!.toStringAsFixed(1)}',
                      formatPhone(s.phone),
                    ].join(' · '),
                    style: TextStyle(color: slate),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAdmin)
                        IconButton(
                          tooltip: l10n.remove,
                          onPressed: () => remove(s),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      IconButton.filledTonal(
                        tooltip: l10n.callPerson(s.name),
                        onPressed: () => callPhone(context, s.phone),
                        icon: const Icon(Icons.call_rounded),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _showAddService(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final validators = Validators(l10n);
  final category = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final location = TextEditingController();
  final added = await BottomSheetForm.show(
    context,
    title: l10n.addService,
    submitLabel: l10n.addService,
    fields: [
      TextFormField(
        controller: category,
        decoration: InputDecoration(labelText: l10n.fieldCategory, hintText: l10n.serviceCategoryHint),
        textCapitalization: TextCapitalization.words,
        maxLength: 30,
        validator: validators.required,
      ),
      TextFormField(
        controller: name,
        decoration: InputDecoration(labelText: l10n.nameField),
        textCapitalization: TextCapitalization.words,
        maxLength: 80,
        validator: validators.required,
      ),
      TextFormField(
        controller: phone,
        decoration: InputDecoration(labelText: l10n.mobileNumberLabel, prefixText: '+91 '),
        keyboardType: TextInputType.phone,
        validator: validators.indianMobile,
      ),
      TextFormField(
        controller: location,
        decoration: InputDecoration(labelText: l10n.areaOptionalField),
        textCapitalization: TextCapitalization.words,
        maxLength: 60,
      ),
    ],
    onSubmit: () => ref.read(profileRepositoryProvider).addService(
          category: category.text.trim(),
          name: name.text.trim(),
          phone: Validators.normalizeIndianMobile(phone.text)!,
          location: location.text.trim().isEmpty ? null : location.text.trim(),
        ),
  );
  for (final c in [category, name, phone, location]) {
    c.dispose();
  }
  if (added == true) {
    ref.invalidate(servicesProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.serviceAdded)));
  }
}
