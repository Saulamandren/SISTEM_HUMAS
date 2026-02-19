// File: frontend/lib/config/app_config.dart

class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://localhost:5000';
  static const String apiVersion = 'v1';
  static const String apiBaseUrl = '$baseUrl/api';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserData = 'user_data';
  static const String keyRememberMe = 'remember_me';

  // App Info
  static const String appName = 'Sistem HUMAS Poltek SSN';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int defaultPageSize = 10;
  static const int maxPageSize = 100;
}
