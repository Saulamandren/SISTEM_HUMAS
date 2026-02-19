import 'package:flutter/foundation.dart';
import '../models/content_model.dart';
import '../models/response_model.dart';
import '../services/content_service.dart';
import 'content_approval.dart';
import 'paginated_content.dart';

class ContentProvider with ChangeNotifier {
  final _contentService = ContentService();

  PaginatedContent? _paginatedContent;
  Content? _currentContent;
  List<ContentApproval>? _approvalHistory;
  bool _isLoading = false;
  String? _errorMessage;

  PaginatedContent? get paginatedContent => _paginatedContent;
  List<Content> get contents => _paginatedContent?.contents ?? [];
  Content? get currentContent => _currentContent;
  List<ContentApproval>? get approvalHistory => _approvalHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Pagination
  int get currentPage => _paginatedContent?.page ?? 1;
  int get totalPages => _paginatedContent?.totalPages ?? 1;
  bool get hasNextPage => _paginatedContent?.hasNextPage ?? false;
  bool get hasPreviousPage => _paginatedContent?.hasPreviousPage ?? false;

  /// Load contents with filters
  Future<void> loadContents({
    int page = 1,
    int perPage = 10,
    String? status,
    int? categoryId,
    int? authorId,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.getContents(
        page: page,
        perPage: perPage,
        status: status,
        categoryId: categoryId,
        authorId: authorId,
        search: search,
      );

      if (response.isSuccess && response.data != null) {
        _paginatedContent = response.data;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load content by ID
  Future<void> loadContentById(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.getContentById(id);

      if (response.isSuccess && response.data != null) {
        _currentContent = response.data;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.createContent(
        title: title,
        body: body,
        categoryId: categoryId,
        excerpt: excerpt,
        featuredImage: featuredImage,
      );

      if (!response.isSuccess) {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.updateContent(
        id: id,
        title: title,
        body: body,
        categoryId: categoryId,
        excerpt: excerpt,
        featuredImage: featuredImage,
      );

      if (!response.isSuccess) {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete content
  Future<ApiResponse<void>> deleteContent(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.deleteContent(id);

      if (!response.isSuccess) {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit content for review
  Future<ApiResponse<void>> submitContent(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.submitContent(id);

      if (!response.isSuccess) {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approve content
  Future<ApiResponse<void>> approveContent(int id, {String? notes}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.approveContent(id, notes: notes);

      if (!response.isSuccess) {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Publish content
  Future<ApiResponse<void>> publishContent(int id, {String? notes}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.publishContent(id, notes: notes);

      if (!response.isSuccess) {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reject content
  Future<ApiResponse<void>> rejectContent(int id,
      {required String notes}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.rejectContent(id, notes: notes);

      if (!response.isSuccess) {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load approval history
  Future<void> loadApprovalHistory(int contentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _contentService.getContentHistory(contentId);

      if (response.isSuccess && response.data != null) {
        _approvalHistory = response.data;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearCurrentContent() {
    _currentContent = null;
    _approvalHistory = null;
    notifyListeners();
  }
}
