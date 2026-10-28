import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/shell/grids_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/photo_field.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_providers.dart';
import '../data/tower_repository.dart';
import '../domain/tower_models.dart';
import 'tower_labels.dart';
import 'tower_providers.dart';

class PostComplaintPage extends ConsumerStatefulWidget {
  const PostComplaintPage({super.key});

  @override
  ConsumerState<PostComplaintPage> createState() => _PostComplaintPageState();
}

class _PostComplaintPageState extends ConsumerState<PostComplaintPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  String? _photoPath;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await ref.read(towerRepositoryProvider).postComplaint(
            ComplaintInput(
              title: _title.text.trim(),
              description: _description.text.trim(),
              category: _category,
              photoPath: _photoPath,
            ),
          );
      ref
        ..invalidate(complaintsProvider)
        ..invalidate(homeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.complaintPosted)));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    return GridsPage(
      title: l10n.postComplaint,
      showMenu: false,
      showNotifications: false,
      body: Form(
        key: _form,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            TextFormField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.fieldTitle),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              validator: (v) => validators.required(v) ?? (v!.trim().length < 3 ? l10n.validationTooShort : null),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.fieldCategory),
              items: [
                for (final c in complaintCategories) DropdownMenuItem(value: c, child: Text(categoryLabel(l10n, c))),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _description,
              decoration: InputDecoration(labelText: l10n.fieldDescription, alignLabelWithHint: true),
              textCapitalization: TextCapitalization.sentences,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000,
              validator: (v) => validators.required(v) ?? (v!.trim().length < 5 ? l10n.validationTooShort : null),
            ),
            const SizedBox(height: AppSpacing.md),
            PhotoField(path: _photoPath, onChanged: (path) => setState(() => _photoPath = path)),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: l10n.postComplaint, isLoading: _posting, onPressed: _post),
          ],
        ),
      ),
    );
  }
}
