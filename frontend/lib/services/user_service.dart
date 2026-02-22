import 'package:dio/dio.dart';
import '../models/response_model.dart';
import '../models/user_model.dart';
import '../models/role_model.dart';
import '../providers/paginated_users.dart';
import 'api_service.dart';

class UserService {
  final _api = ApiService();

  Future<ApiResponse<PaginatedUsers>> getUsers({
    int page = 1,
    int perPage = 10,
    int? roleId,
    String? search,
    bool? isActive,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (roleId != null) queryParams['role_id'] = roleId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (isActive != null) {
        queryParams['is_active'] = isActive ? 'true' : 'false';
      }

      final response =
          await _api.get('/users/', queryParameters: queryParams);

      return ApiResponse.fromJson(
        response.data,
        (data) => PaginatedUsers.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil data pengguna',
      );
    } catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  Future<ApiResponse<User>> getUserById(int id) async {
    try {
      final response = await _api.get('/users/$id');
      return ApiResponse.fromJson(
        response.data,
        (data) => User.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil data user',
      );
    }
  }

  Future<ApiResponse<List<Role>>> getRoles() async {
    try {
      final response = await _api.get('/users/roles');
      return ApiResponse.fromJson(
        response.data,
        (data) {
          final roles = data['roles'] as List<dynamic>? ?? [];
          return roles
              .map((item) => Role.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil data role',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createUser({
    required String username,
    required String email,
    required String fullName,
    required int roleId,
    String? nip,
    String? password,
  }) async {
    try {
      final response = await _api.post('/users/', data: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
        'nip': nip,
        'role_id': roleId,
      });

      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal membuat user',
      );
    }
  }

  Future<ApiResponse<void>> updateUser({
    required int id,
    required String fullName,
    required String email,
    required int roleId,
    bool isActive = true,
    String? nip,
  }) async {
    try {
      final response = await _api.put('/users/$id', data: {
        'full_name': fullName,
        'email': email,
        'nip': nip,
        'role_id': roleId,
        'is_active': isActive,
      });

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal memperbarui user',
      );
    }
  }

  Future<ApiResponse<void>> deleteUser(int id) async {
    try {
      final response = await _api.delete('/users/$id');
      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal menghapus user',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> resetPassword(int id) async {
    try {
      final response = await _api.post('/users/$id/reset-password');
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal reset password',
      );
    }
  }
}
