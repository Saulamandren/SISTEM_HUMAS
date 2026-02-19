// File: frontend/lib/services/storage_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  // Initialize
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Secure Storage (for tokens)
  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: 'access_token', value: token);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: 'refresh_token', value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _secureStorage.write(key: 'user_data', value: jsonEncode(userData));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final data = await _secureStorage.read(key: 'user_data');
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'user_data');
  }

  // Regular Preferences (for non-sensitive data)
  Future<void> setRememberMe(bool value) async {
    await _prefs?.setBool('remember_me', value);
  }

  bool getRememberMe() {
    return _prefs?.getBool('remember_me') ?? false;
  }

  Future<void> saveLastUsername(String username) async {
    await _prefs?.setString('last_username', username);
  }

  String? getLastUsername() {
    return _prefs?.getString('last_username');
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs?.clear();
  }
}
