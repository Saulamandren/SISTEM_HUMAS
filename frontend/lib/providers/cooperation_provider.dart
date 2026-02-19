import 'package:flutter/foundation.dart';
import '../models/cooperation_model.dart';
import '../models/response_model.dart';
import '../services/cooperation_service.dart';

class CooperationProvider with ChangeNotifier {
  final _cooperationService = CooperationService();

  List<Cooperation> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Cooperation> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCooperations({String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response =
          await _cooperationService.getCooperations(status: status);
      if (response.isSuccess && response.data != null) {
        _items = response.data!;
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

  Future<ApiResponse<Map<String, dynamic>>> createCooperation({
    required String institutionName,
    required String contactName,
    required String email,
    required String phone,
    required String purpose,
    required DateTime eventDate,
    required String documentName,
    required String documentBase64,
    String? documentMime,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _cooperationService.createCooperation(
        institutionName: institutionName,
        contactName: contactName,
        email: email,
        phone: phone,
        purpose: purpose,
        eventDate: eventDate,
        documentName: documentName,
        documentBase64: documentBase64,
        documentMime: documentMime,
      );

      if (response.isSuccess) {
        await loadCooperations();
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

  Future<ApiResponse<void>> verifyCooperation(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _cooperationService.verifyCooperation(id);
      if (response.isSuccess) {
        await loadCooperations();
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

  Future<ApiResponse<void>> approveCooperation(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _cooperationService.approveCooperation(id);
      if (response.isSuccess) {
        await loadCooperations();
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

  Future<ApiResponse<void>> rejectCooperation(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _cooperationService.rejectCooperation(id);
      if (response.isSuccess) {
        await loadCooperations();
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

  Future<ApiResponse<Map<String, dynamic>>> getDocument(int id) async {
    try {
      return await _cooperationService.getDocument(id);
    } catch (e) {
      return ApiResponse(status: 'error', message: 'Terjadi kesalahan: $e');
    }
  }
}
