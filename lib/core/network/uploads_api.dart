import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/data/auth_providers.dart';
import '../config/app_config.dart';
import 'api_call.dart';

/// Uploads photos and resolves stored paths ("/uploads/…") to URLs.
class UploadsApi {
  UploadsApi(this._dio, this._config);

  final Dio _dio;
  final AppConfig _config;

  /// Returns the stored path to save on a record.
  Future<String> uploadImage(XFile file) => apiCall(() async {
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name),
        });
        final response = await _dio.post<Json>('/uploads', data: form);
        return response.data!['url'] as String;
      });

  String urlFor(String path) => '${_config.apiBaseUrl}$path';
}

final uploadsApiProvider = Provider<UploadsApi>(
  (ref) => UploadsApi(ref.watch(authedDioProvider), ref.watch(appConfigProvider)),
);

/// Full URL for a stored photo path, or null.
final photoUrlProvider = Provider.family<String?, String?>(
  (ref, path) => path == null ? null : ref.watch(uploadsApiProvider).urlFor(path),
);
