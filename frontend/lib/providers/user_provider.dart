import 'package:flutter/foundation.dart';
import '../models/response_model.dart';
import '../models/user_model.dart';
import '../models/role_model.dart';
import '../providers/paginated_users.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  final _userService = UserService();

  PaginatedUsers? _paginatedUsers;
  User? _currentUser;
  List<Role> _roles = [];
  bool _isLoading = false;
  String? _errorMessage;

  int _lastPage = 1;
  int _lastPerPage = 10;
  int? _lastRoleId;
  String? _lastSearch;
  bool? _lastIsActive;

  PaginatedUsers? get paginatedUsers => _paginatedUsers;
  List<User> get users => _paginatedUsers?.users ?? [];
  User? get currentUser => _currentUser;
  List<Role> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadUsers({
    int page = 1,
    int perPage = 10,
    int? roleId,
    String? search,
    bool? isActive,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _lastPage = page;
    _lastPerPage = perPage;
    _lastRoleId = roleId;
    _lastSearch = search;
    _lastIsActive = isActive;

    try {
      final response = await _userService.getUsers(
        page: page,
        perPage: perPage,
        roleId: roleId,
        search: search,
        isActive: isActive,
      );

      if (response.isSuccess && response.data != null) {
        _paginatedUsers = response.data;
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

  Future<void> refreshUsers() async {
    await loadUsers(
      page: _lastPage,
      perPage: _lastPerPage,
      roleId: _lastRoleId,
      search: _lastSearch,
      isActive: _lastIsActive,
    );
  }

  Future<ApiResponse<User>> loadUserById(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _userService.getUserById(id);
      if (response.isSuccess && response.data != null) {
        _currentUser = response.data;
      } else {
        _errorMessage = response.message;
      }
      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(status: 'error', message: _errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ApiResponse<List<Role>>> loadRoles() async {
    try {
      final response = await _userService.getRoles();
      if (response.isSuccess && response.data != null) {
        _roles = response.data!;
        notifyListeners();
      }
      return response;
    } catch (e) {
      return ApiResponse(
        status: 'error',
        message: 'Terjadi kesalahan: $e',
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _userService.createUser(
        username: username,
        email: email,
        fullName: fullName,
        roleId: roleId,
        nip: nip,
        password: password,
      );

      if (response.isSuccess) {
        await refreshUsers();
      } else {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(status: 'error', message: _errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _userService.updateUser(
        id: id,
        fullName: fullName,
        email: email,
        roleId: roleId,
        isActive: isActive,
        nip: nip,
      );

      if (response.isSuccess) {
        await refreshUsers();
      } else {
        _errorMessage = response.message;
      }

      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(status: 'error', message: _errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ApiResponse<void>> deleteUser(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _userService.deleteUser(id);
      if (response.isSuccess) {
        await refreshUsers();
      } else {
        _errorMessage = response.message;
      }
      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(status: 'error', message: _errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> resetPassword(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _userService.resetPassword(id);
      if (!response.isSuccess) {
        _errorMessage = response.message;
      }
      return response;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return ApiResponse(status: 'error', message: _errorMessage);
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
