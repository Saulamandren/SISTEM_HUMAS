import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  // Base URL - sesuaikan dengan backend Anda
  static const String baseUrl = 'http://localhost:5000/api';

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptor untuk auto-attach token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Get token from secure storage
          final token = await _storage.read(key: 'access_token');

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          print('[API Request] ${options.method} ${options.path}');
          print('[API Headers] ${options.headers}');

          return handler.next(options);
        },
        onResponse: (response, handler) {
          print(
              '[API Response] ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) async {
          print(
              '[API Error] ${error.response?.statusCode} ${error.requestOptions.path}');
          print('[API Error Data] ${error.response?.data}');

          // Handle 401 Unauthorized - token expired
          if (error.response?.statusCode == 401) {
            // TODO: Auto refresh token or logout
            print('[API] Unauthorized - Token may be expired');
          }

          return handler.next(error);
        },
      ),
    );
  }

  // GET Request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      print('[GET Error] $path: ${e.message}');
      rethrow;
    }
  }

  // POST Request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      print('[POST Error] $path: ${e.message}');
      rethrow;
    }
  }

  // PUT Request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      print('[PUT Error] $path: ${e.message}');
      rethrow;
    }
  }

  // DELETE Request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      print('[DELETE Error] $path: ${e.message}');
      rethrow;
    }
  }

  // PATCH Request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      print('[PATCH Error] $path: ${e.message}');
      rethrow;
    }
  }

  // Save token to secure storage
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
    print('[API] Token saved');
  }

  // Get token from secure storage
  Future<String?> getToken() async {
    final token = await _storage.read(key: 'access_token');
    return token;
  }

  // Remove token from secure storage
  Future<void> removeToken() async {
    await _storage.delete(key: 'access_token');
    print('[API] Token removed');
  }

  // Check if token exists
  Future<bool> hasToken() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  // Get Dio instance (for advanced usage)
  Dio get dio => _dio;

  // Update base URL (if needed)
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
    print('[API] Base URL updated to: $newBaseUrl');
  }

  // Set timeout
  void setTimeout(Duration timeout) {
    _dio.options.connectTimeout = timeout;
    _dio.options.receiveTimeout = timeout;
    print('[API] Timeout set to: ${timeout.inSeconds}s');
  }
}
