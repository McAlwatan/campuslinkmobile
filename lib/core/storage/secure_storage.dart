import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessToken = 'access_token';
  static const _refreshToken = 'refresh_token';
  static const _pin = 'user_pin';
  static const _userId = 'user_id';
  static const _userName = 'user_name';

  // tokens
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessToken, value: accessToken);
    await _storage.write(key: _refreshToken, value: refreshToken);
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: _accessToken);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshToken);

  // pin
  static Future<void> savePin(String pin) =>
      _storage.write(key: _pin, value: pin);

  static Future<String?> getPin() => _storage.read(key: _pin);

  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pin);
    return pin != null && pin.isNotEmpty;
  }

  // user info
  static Future<void> saveUserInfo({
    required String userId,
    required String userName,
  }) async {
    await _storage.write(key: _userId, value: userId);
    await _storage.write(key: _userName, value: userName);
  }

  static Future<String?> getUserId() => _storage.read(key: _userId);
  static Future<String?> getUserName() => _storage.read(key: _userName);

  // clear everything on logout
  static Future<void> clearAll() => _storage.deleteAll();

  // check if user has an active session
  static Future<bool> hasSession() async {
    final token = await _storage.read(key: _accessToken);
    return token != null && token.isNotEmpty;
  }
}