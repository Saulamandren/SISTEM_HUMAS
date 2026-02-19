import 'package:dio/dio.dart';
import '../models/content_model.dart';
import '../models/response_model.dart';
import '../providers/content_approval.dart';
import '../providers/paginated_content.dart';
import 'api_service.dart';

class ContentService {
  final _api = ApiService();

  /// Get contents with filters
  Future<ApiResponse<PaginatedContent>> getContents({
    int page = 1,
    int perPage = 10,
    String? status,
    int? categoryId,
    int? authorId,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };

      if (status != null) queryParams['status'] = status;
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (authorId != null) queryParams['author_id'] = authorId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response =
          await _api.get('/contents/', queryParameters: queryParams);

      print('Get contents response: ${response.data}');

      return ApiResponse.fromJson(
        response.data,
        (data) => PaginatedContent.fromJson(data),
      );
    } on DioException catch (e) {
      print('Get contents error: ${e.response?.data}');
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil data konten',
      );
    } catch (e) {
      print('Get contents unexpected error: $e');
      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Get content by ID
  Future<ApiResponse<Content>> getContentById(int id) async {
    try {
      final response = await _api.get('/contents/$id');

      return ApiResponse.fromJson(
        response.data,
        (data) => Content.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil data konten',
      );
    }
  }

  /// Create content
  Future<ApiResponse<Map<String, dynamic>>> createContent({
    required String title,
    required String body,
    required int categoryId,
    String? excerpt,
    String? featuredImage,
  }) async {
    try {
      final response = await _api.post('/contents/', data: {
        'title': title,
        'body': body,
        'category_id': categoryId,
        'excerpt': excerpt,
        'featured_image': featuredImage,
      });

      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal membuat konten',
      );
    }
  }

  /// Update content
  Future<ApiResponse<void>> updateContent({
    required int id,
    required String title,
    required String body,
    required int categoryId,
    String? excerpt,
    String? featuredImage,
  }) async {
    try {
      final response = await _api.put('/contents/$id', data: {
        'title': title,
        'body': body,
        'category_id': categoryId,
        'excerpt': excerpt,
        'featured_image': featuredImage,
      });

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal memperbarui konten',
      );
    }
  }

  /// Delete content
  Future<ApiResponse<void>> deleteContent(int id) async {
    try {
      final response = await _api.delete('/contents/$id');

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal menghapus konten',
      );
    }
  }

  /// Submit content for review
  Future<ApiResponse<void>> submitContent(int id) async {
    try {
      final response = await _api.post('/contents/$id/submit');

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal submit konten',
      );
    }
  }

  /// Approve content
  Future<ApiResponse<void>> approveContent(int id, {String? notes}) async {
    try {
      final response = await _api.post('/contents/$id/approve', data: {
        'notes': notes,
      });

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal approve konten',
      );
    }
  }

  /// Publish content
  Future<ApiResponse<void>> publishContent(int id, {String? notes}) async {
    try {
      final response = await _api.post('/contents/$id/publish', data: {
        'notes': notes,
      });

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal publish konten',
      );
    }
  }

  /// Reject content
  Future<ApiResponse<void>> rejectContent(int id,
      {required String notes}) async {
    try {
      final response = await _api.post('/contents/$id/reject', data: {
        'notes': notes,
      });

      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal reject konten',
      );
    }
  }

  /// Get content approval history
  Future<ApiResponse<List<ContentApproval>>> getContentHistory(int id) async {
    try {
      final response = await _api.get('/contents/$id/history');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return data.map((item) => ContentApproval.fromJson(item)).toList();
          }
          return [];
        },
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil history',
      );
    }
  }
}
