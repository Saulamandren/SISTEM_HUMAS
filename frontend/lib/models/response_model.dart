// File: lib/models/response_model.dart

import 'user_model.dart'; // ✅ TAMBAHKAN INI - Import User class

class ApiResponse<T> {
  final String status;
  final String? message;
  final T? data;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      status: json['status'] ?? 'error',
      message: json['message'],
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
      errors: json['errors'],
    );
  }
}

class AuthResponse {
  final User user;
  final TokenData tokens;

  AuthResponse({
    required this.user,
    required this.tokens,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    final userJson =
        userRaw is Map<String, dynamic> ? userRaw : <String, dynamic>{};

    final tokensRaw = json['tokens'];
    Map<String, dynamic> tokensJson;
    if (tokensRaw is Map<String, dynamic>) {
      tokensJson = tokensRaw;
    } else {
      tokensJson = {
        'access_token': json['access_token'],
        'refresh_token': json['refresh_token'],
        'expires_in': json['expires_in'],
      };
    }

    return AuthResponse(
      user: User.fromJson(userJson),
      tokens: TokenData.fromJson(tokensJson),
    );
  }
}

class TokenData {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  TokenData({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory TokenData.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    String parseString(dynamic value, {String fallback = ''}) {
      if (value == null) return fallback;
      return value.toString();
    }

    return TokenData(
      accessToken: parseString(json['access_token']),
      refreshToken: parseString(json['refresh_token']),
      expiresIn: parseInt(json['expires_in']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
    };
  }
}
