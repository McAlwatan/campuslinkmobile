import 'package:dio/dio.dart';
import 'package:campuslink/core/storage/secure_storage.dart';

class ApiClient {
  static const baseUrl = 'http://185.194.219.112'; // Android emulator → localhost
  // For physical device use your PC's local IP e.g. 'http://192.168.x.x:8000'

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ))..interceptors.add(_AuthInterceptor());

  static Dio get instance => _dio;

  static Future<String> getToken() async {
  return await SecureStorage.getAccessToken() ?? '';
}
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // try refresh
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final response = await Dio().post(
            '${ApiClient.baseUrl}/auth/refresh',
            data: {'refresh_token': refreshToken},
          );
          final newAccess = response.data['access_token'];
          final newRefresh = response.data['refresh_token'];
          await SecureStorage.saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
          // retry original request
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retried = await ApiClient.instance.fetch(err.requestOptions);
          return handler.resolve(retried);
        } catch (_) {
          await SecureStorage.clearAll();
        }
      }
    }
    handler.next(err);
  }
}

