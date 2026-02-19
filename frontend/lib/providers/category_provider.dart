import 'package:flutter/foundation.dart';
import '../models/category_model.dart' as models; // ← TAMBAH ALIAS
import '../models/response_model.dart';
import '../services/category_service.dart';

class CategoryProvider with ChangeNotifier {
  final _categoryService = CategoryService();

  List<models.Category> _categories = []; // ← PAKAI ALIAS
  bool _isLoading = false;
  String? _errorMessage;

  List<models.Category> get categories => _categories; // ← PAKAI ALIAS
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load all categories
  Future<void> loadCategories({bool activeOnly = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response =
          await _categoryService.getCategories(activeOnly: activeOnly);

      if (response.isSuccess && response.data != null) {
        _categories = response.data!;
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

  /// Create category
  Future<ApiResponse<Map<String, dynamic>>> createCategory({
    required String name,
    required String description,
    String icon = 'article',
    String color = '#1976D2',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _categoryService.createCategory(
        name: name,
        description: description,
        icon: icon,
        color: color,
      );

      if (response.isSuccess) {
        await loadCategories();
      } else {
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

  /// Update category
  Future<ApiResponse<void>> updateCategory({
    required int id,
    required String name,
    required String description,
    required String icon,
    required String color,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _categoryService.updateCategory(
        id: id,
        name: name,
        description: description,
        icon: icon,
        color: color,
      );

      if (response.isSuccess) {
        await loadCategories();
      } else {
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

  /// Delete category
  Future<ApiResponse<void>> deleteCategory(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _categoryService.deleteCategory(id);

      if (response.isSuccess) {
        await loadCategories();
      } else {
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
