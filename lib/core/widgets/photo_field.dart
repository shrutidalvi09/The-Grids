import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../network/api_exception.dart';
import '../network/uploads_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Optional photo: pick from gallery or camera, uploaded immediately; reports
/// the stored path (e.g. "/uploads/ab12….jpg") through [onChanged].
class PhotoField extends ConsumerStatefulWidget {
  const PhotoField({super.key, required this.path, required this.onChanged, this.picker});

  final String? path;
  final ValueChanged<String?> onChanged;

  /// Injectable for tests.
  final ImagePicker? picker;

  @override
  ConsumerState<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends ConsumerState<PhotoField> {
  bool _uploading = false;

  Future<void> _pick(ImageSource source) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final file = await (widget.picker ?? ImagePicker()).pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      widget.onChanged(await ref.read(uploadsApiProvider).uploadImage(file));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _chooseSource() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      useRootNavigator: true, // above the bottom nav bar
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(l10n.photoFromGallery),
              onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(l10n.photoFromCamera),
              onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final url = ref.watch(photoUrlProvider(widget.path));
    final grids = GridsColors.of(context);

    return Semantics(
      button: true,
      label: url == null ? l10n.addPhoto : l10n.changePhoto,
      child: Material(
        color: grids.card,
        borderRadius: const BorderRadius.all(AppRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _uploading ? null : _chooseSource,
          child: SizedBox(
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  Image.network(url, fit: BoxFit.cover)
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, size: 36, color: grids.slate),
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.addPhoto, style: TextStyle(color: grids.slate)),
                    ],
                  ),
                if (_uploading)
                  ColoredBox(
                    color: Colors.black38,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: AppSpacing.sm),
                          Text(l10n.uploadingPhoto, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                if (url != null && !_uploading)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      tooltip: l10n.removePhoto,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => widget.onChanged(null),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
