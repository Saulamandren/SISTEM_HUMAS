import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/response_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final _api = ApiService();
  final _storage = StorageService();

  /// Register new user
  Future<ApiResponse<Map<String, dynamic>>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? nip,
    int roleId = 1,
  }) async {
    try {
      final response = await _api.post('/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
        'nip': nip,
        'role_id': roleId,
      });

      print('Register response: ${response.data}'); // Debug

      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      print('Register error: ${e.response?.data}'); // Debug

      return ApiResponse(
        status: 'error',
        message:
            e.response?.data['message'] ?? 'Terjadi kesalahan saat registrasi',
      );
    } catch (e) {
      print('Register unexpected error: $e'); // Debug

      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Login user
  Future<ApiResponse<AuthResponse>> login({
    required String username,
    required String password,
  }) async {
    try {
      print('Login request: username=$username'); // Debug

      final response = await _api.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      print('Login response status: ${response.statusCode}'); // Debug
      print('Login response data: ${response.data}'); // Debug

      final apiResponse = ApiResponse.fromJson(
        response.data,
        (data) {
          print('Parsing auth data: $data'); // Debug

          try {
            return AuthResponse.fromJson(data);
          } catch (e) {
            print('Error parsing AuthResponse: $e'); // Debug
            rethrow;
          }
        },
      );

      if (apiResponse.isSuccess && apiResponse.data != null) {
        print('Login successful, saving tokens...'); // Debug

        await _storage.saveAccessToken(apiResponse.data!.tokens.accessToken);
        await _storage.saveRefreshToken(apiResponse.data!.tokens.refreshToken);

        print('Saving user data: ${apiResponse.data!.user.toJson()}'); // Debug
        await _storage.saveUserData(apiResponse.data!.user.toJson());

        print('Login completed successfully'); // Debug
      } else {
        print('Login failed: ${apiResponse.message}'); // Debug
      }

      return apiResponse;
    } on DioException catch (e) {
      print('Login DioException:'); // Debug
      print('  Status code: ${e.response?.statusCode}'); // Debug
      print('  Response data: ${e.response?.data}'); // Debug
      print('  Error message: ${e.message}'); // Debug

      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Terjadi kesalahan saat login',
      );
    } catch (e, stackTrace) {
      print('Login unexpected error: $e'); // Debug
      print('Stack trace: $stackTrace'); // Debug

      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Logout user
  Future<ApiResponse<void>> logout() async {
    try {
      print('Logout request'); // Debug

      await _api.post('/auth/logout');
      await _storage.clearAuthData();

      print('Logout successful'); // Debug

      return ApiResponse(
        status: 'success',
        message: 'Logout berhasil',
      );
    } on DioException catch (e) {
      print('Logout error: ${e.response?.data}'); // Debug

      // Clear local data even if API call fails
      await _storage.clearAuthData();

      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Terjadi kesalahan saat logout',
      );
    } catch (e) {
      print('Logout unexpected error: $e'); // Debug

      // Clear local data even if error occurs
      await _storage.clearAuthData();

      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Get user profile
  Future<ApiResponse<User>> getProfile() async {
    try {
      print('Get profile request'); // Debug

      final response = await _api.get('/auth/profile');

      print('Get profile response: ${response.data}'); // Debug

      return ApiResponse.fromJson(
        response.data,
        (data) {
          print('Parsing user profile: $data'); // Debug
          return User.fromJson(data);
        },
      );
    } on DioException catch (e) {
      print('Get profile error: ${e.response?.data}'); // Debug

      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil data profil',
      );
    } catch (e) {
      print('Get profile unexpected error: $e'); // Debug

      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Update user profile
  Future<ApiResponse<Map<String, dynamic>>> updateProfile({
    required String fullName,
    required String email,
    String? nip,
  }) async {
    try {
      print(
          'Update profile request: fullName=$fullName, email=$email'); // Debug

      final response = await _api.put('/auth/profile', data: {
        'full_name': fullName,
        'email': email,
        'nip': nip,
      });

      print('Update profile response: ${response.data}'); // Debug

      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      print('Update profile error: ${e.response?.data}'); // Debug

      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal memperbarui profil',
      );
    } catch (e) {
      print('Update profile unexpected error: $e'); // Debug

      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Change password
  Future<ApiResponse<void>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      print('Change password request'); // Debug

      final response = await _api.post('/auth/change-password', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      });

      print('Change password response: ${response.data}'); // Debug

      // Clear tokens after password change (user must login again)
      await _storage.clearAuthData();

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      print('Change password error: ${e.response?.data}'); // Debug

      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengubah password',
      );
    } catch (e) {
      print('Change password unexpected error: $e'); // Debug

      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final token = await _storage.getAccessToken();
      final isLoggedIn = token != null && token.isNotEmpty;

      print('isLoggedIn check: $isLoggedIn'); // Debug

      return isLoggedIn;
    } catch (e) {
      print('isLoggedIn error: $e'); // Debug
      return false;
    }
  }

  /// Get current user from storage
  Future<User?> getCurrentUser() async {
    try {
      print('Getting current user from storage'); // Debug

      final userData = await _storage.getUserData();

      if (userData != null) {
        print('Current user data: $userData'); // Debug
        return User.fromJson(userData);
      }

      print('No current user in storage'); // Debug
      return null;
    } catch (e) {
      print('Get current user error: $e'); // Debug
      return null;
    }
  }

  /// Refresh access token using refresh token
  Future<ApiResponse<Map<String, dynamic>>> refreshToken() async {
    try {
      print('Refresh token request'); // Debug

      final refreshToken = await _storage.getRefreshToken();

      if (refreshToken == null) {
        return ApiResponse(
          status: 'error',
          message: 'No refresh token available',
        );
      }

      final response = await _api.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      print('Refresh token response: ${response.data}'); // Debug

      // Save new tokens
      if (response.data['status'] == 'success') {
        final newAccessToken = response.data['data']['access_token'];
        final newRefreshToken = response.data['data']['refresh_token'];

        await _storage.saveAccessToken(newAccessToken);
        await _storage.saveRefreshToken(newRefreshToken);

        print('New tokens saved'); // Debug
      }

      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      print('Refresh token error: ${e.response?.data}'); // Debug

      // Clear auth data if refresh fails
      await _storage.clearAuthData();

      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal refresh token',
      );
    } catch (e) {
      print('Refresh token unexpected error: $e'); // Debug

      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }
}
