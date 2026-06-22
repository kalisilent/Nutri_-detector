import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import '../storage/token_storage.dart';

/// Backend base URL — point at your Cloud Run service in release builds.
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080/api/v1', // Android emulator → localhost
);

final tokenStorageProvider = Provider((ref) => TokenStorage());

final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);

  final dio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60), // OCR can take a while
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.access;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      // Auto-refresh on 401 once, then retry the original request.
      if (error.response?.statusCode == 401 &&
          error.requestOptions.extra['retried'] != true) {
        final refresh = await storage.refresh;
        if (refresh != null) {
          try {
            final resp = await Dio(BaseOptions(baseUrl: kApiBaseUrl)).post(
              '/auth/refresh',
              data: {'refresh_token': refresh},
            );
            await storage.save(
                resp.data['access_token'], resp.data['refresh_token']);
            final opts = error.requestOptions..extra['retried'] = true;
            opts.headers['Authorization'] =
                'Bearer ${resp.data['access_token']}';
            final retry = await dio.fetch(opts);
            return handler.resolve(retry);
          } catch (_) {
            await storage.clear();
          }
        }
      }
      handler.next(error);
    },
  ));

  return dio;
});

/// Convert Dio errors into user-friendly AppExceptions.
AppException mapDioError(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError) {
    return const AppException('No internet connection. Please try again.');
  }
  final code = e.response?.statusCode;
  final detail = e.response?.data is Map
      ? (e.response!.data['detail']?.toString() ?? 'Something went wrong')
      : 'Something went wrong';
  return AppException(detail, statusCode: code);
}
