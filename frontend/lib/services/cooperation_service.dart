import 'package:dio/dio.dart';
import '../models/cooperation_model.dart';
import '../models/response_model.dart';
import 'api_service.dart';

class CooperationService {
  final _api = ApiService();

  Future<ApiResponse<List<Cooperation>>> getCooperations(
      {String? status}) async {
    try {
      final response = await _api.get(
        '/cooperations/',
        queryParameters: status != null ? {'status': status} : null,
      );

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return data
                .map((item) => Cooperation.fromJson(item))
                .toList();
          }
          return [];
        },
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message:
            e.response?.data['message'] ?? 'Gagal mengambil data kerjasama',
      );
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
    try {
      final response = await _api.post('/cooperations/', data: {
        'institution_name': institutionName,
        'contact_name': contactName,
        'email': email,
        'phone': phone,
        'purpose': purpose,
        'event_date': eventDate.toIso8601String().substring(0, 10),
        'document_name': documentName,
        'document_mime': documentMime,
        'document_base64': documentBase64,
      });

      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengirim pengajuan',
      );
    }
  }

  Future<ApiResponse<void>> verifyCooperation(int id) async {
    try {
      final response = await _api.post('/cooperations/$id/verify');
      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal verifikasi pengajuan',
      );
    }
  }

  Future<ApiResponse<void>> approveCooperation(int id) async {
    try {
      final response = await _api.post('/cooperations/$id/approve');
      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal menyetujui pengajuan',
      );
    }
  }

  Future<ApiResponse<void>> rejectCooperation(int id) async {
    try {
      final response = await _api.post('/cooperations/$id/reject');
      return ApiResponse.fromJson(response.data, null);
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal menolak pengajuan',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getDocument(int id) async {
    try {
      final response = await _api.get('/cooperations/$id/document');
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      return ApiResponse(
        status: 'error',
        message: e.response?.data['message'] ?? 'Gagal mengambil dokumen',
      );
    }
  }
}
