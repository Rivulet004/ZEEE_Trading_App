import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000', // Use 'http://10.0.2.2:8000' for Android Emulator matching localhost
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final _storage = const FlutterSecureStorage();
  
  // Callback trigger when authorization refresh token fails entirely (force logout)
  void Function()? onAuthFailure;

  ApiClient() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await _storage.read(key: 'access_token');
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        // Attempt token refresh on unauthorized 401 response status code
        if (error.response?.statusCode == 401) {
          final requestOptions = error.requestOptions;
          
          // Skip if the request was actually to login/refresh to avoid infinite loops
          if (requestOptions.path.contains('/api/accounts/login/') ||
              requestOptions.path.contains('/api/token/refresh/')) {
            return handler.next(error);
          }

          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken != null) {
            try {
              // Create isolated Dio instance to avoid interceptor recursion
              final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
              final response = await refreshDio.post(
                '/api/token/refresh/',
                data: {'refresh': refreshToken},
              );

              if (response.statusCode == 200) {
                final newAccessToken = response.data['access'];
                await _storage.write(key: 'access_token', value: newAccessToken);

                // Update request header and retry original transaction request
                requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                
                final clonedResponse = await dio.request(
                  requestOptions.path,
                  options: Options(
                    method: requestOptions.method,
                    headers: requestOptions.headers,
                  ),
                  data: requestOptions.data,
                  queryParameters: requestOptions.queryParameters,
                );
                return handler.resolve(clonedResponse);
              }
            } catch (refreshError) {
              // Refresh token is expired or invalid - clear keychain storage and fire failure callback
              await _storage.delete(key: 'access_token');
              await _storage.delete(key: 'refresh_token');
              
              if (onAuthFailure != null) {
                onAuthFailure!();
              }
            }
          }
        }
        return handler.next(error);
      },
    ));
  }
}
