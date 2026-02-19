// File: lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/response_model.dart';
import '../services/auth_service.dart'; // ✅ BENAR - path relatif ke services
import '../services/storage_service.dart'; // ✅ BENAR

class AuthProvider with ChangeNotifier {
  final _authService = AuthService();
  final _storage = StorageService();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        _currentUser = await _authService.getCurrentUser();

        final response = await _authService.getProfile();
        if (response.isSuccess && response.data != null) {
          _currentUser = response.data;
          await _storage.saveUserData(_currentUser!.toJson());
        } else {
          await logout();
        }
      }
    } catch (e) {
      debugPrint('Initialize error: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ApiResponse<AuthResponse>> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        username: username,
        password: password,
      );

      if (response.isSuccess && response.data != null) {
        _currentUser = response.data!.user;

        await _storage.setRememberMe(rememberMe);
        if (rememberMe) {
          await _storage.saveLastUsername(username);
        }
      } else {
        _errorMessage = response.message;
      }

      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan: $e';
      notifyListeners();

      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? nip,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
        nip: nip,
      );

      if (!response.isSuccess) {
        _errorMessage = response.message;
      }

      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan: $e';
      notifyListeners();

      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateProfile({
    required String fullName,
    required String email,
    String? nip,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.updateProfile(
        fullName: fullName,
        email: email,
        nip: nip,
      );

      if (response.isSuccess) {
        final profileResponse = await _authService.getProfile();
        if (profileResponse.isSuccess && profileResponse.data != null) {
          _currentUser = profileResponse.data;
          await _storage.saveUserData(_currentUser!.toJson());
        }
      } else {
        _errorMessage = response.message;
      }

      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan: $e';
      notifyListeners();

      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    }
  }

  Future<ApiResponse<void>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (response.isSuccess) {
        _currentUser = null;
      } else {
        _errorMessage = response.message;
      }

      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan: $e';
      notifyListeners();

      return ApiResponse(
        status: 'error',
        message: _errorMessage,
      );
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
