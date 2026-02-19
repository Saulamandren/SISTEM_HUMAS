import 'package:dio/dio.dart';
import '../models/category_model.dart';
import '../models/response_model.dart';
import 'api_service.dart';

class CategoryService {
  final _api = ApiService();

  /// Get all categories
  Future<ApiResponse<List<Category>>> getCategories(
      {bool activeOnly = true}) async {
    try {
      final response = await _api.get(
        '/categories/',
        queryParameters: {'active_only': activeOnly},
      );

      print('Get categories response: ${response.data}');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return data.map((item) => Category.fromJson(item)).toList();
          }
          return [];
        },
      );
    } on DioException catch (e) {
      print('Get categories error: ${e.response?.data}');
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil data kategori',
      );
    } catch (e) {
      print('Get categories unexpected error: $e');
      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Get category by ID
  Future<ApiResponse<Category>> getCategoryById(int id) async {
    try {
      final response = await _api.get('/categories/$id');

      return ApiResponse.fromJson(
        response.data,
        (data) => Category.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil data kategori',
      );
    }
  }

  /// Create category
  Future<ApiResponse<Map<String, dynamic>>> createCategory({
    required String name,
    required String description,
    String icon = 'article',
    String color = '#1976D2',
  }) async {
    try {
      final response = await _api.post('/categories/', data: {
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
      });

      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal membuat kategori',
      );
    }
  }

  /// Update category
  Future<ApiResponse<void>> updateCategory({
    required int id,
    required String name,
    required String description,
    required String icon,
    required String color,
  }) async {
    try {
      final response = await _api.put('/categories/$id', data: {
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
      });

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal memperbarui kategori',
      );
    }
  }

  /// Delete category
  Future<ApiResponse<void>> deleteCategory(int id) async {
    try {
      final response = await _api.delete('/categories/$id');

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal menghapus kategori',
      );
    }
  }
}
