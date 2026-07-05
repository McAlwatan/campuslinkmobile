import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campuslink/core/storage/secure_storage.dart';
import 'package:campuslink/core/api/api_client.dart';

class AuthState {
  final bool isLoggedIn;
  final bool hasPin;
  final Map<String, dynamic>? user;

  const AuthState({
    this.isLoggedIn = false,
    this.hasPin = false,
    this.user,
  });

  AuthState copyWith({bool? isLoggedIn, bool? hasPin, Map<String, dynamic>? user}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      hasPin: hasPin ?? this.hasPin,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> init() async {
    final hasSession = await SecureStorage.hasSession();
    final hasPin = await SecureStorage.hasPin();
    Map<String, dynamic>? user;
    if (hasSession) {
      try {
        final userId = await SecureStorage.getUserId();
        final userName = await SecureStorage.getUserName();
        if (userId != null) user = {'id': userId, 'full_name': userName ?? ''};
      } catch (_) {}
    }
    state = AuthState(isLoggedIn: hasSession, hasPin: hasPin, user: user);
  }

  Future<bool> login(String email, String password) async {
    try {
      final res = await ApiClient.instance.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      await SecureStorage.saveTokens(
        accessToken: res.data['access_token'],
        refreshToken: res.data['refresh_token'],
      );
      final profile = await ApiClient.instance.get('/users/me');
      await SecureStorage.saveUserInfo(
        userId: profile.data['id'],
        userName: profile.data['full_name'],
      );
      state = state.copyWith(isLoggedIn: true, user: profile.data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> register(String email, String fullName, String password, String? universityId) async {
    try {
      final res = await ApiClient.instance.post('/auth/signup', data: {
        'email': email,
        'full_name': fullName,
        'password': password,
        if (universityId != null && universityId.isNotEmpty) 'university_id': universityId,
      });
      await SecureStorage.saveTokens(
        accessToken: res.data['access_token'],
        refreshToken: res.data['refresh_token'],
      );
      final profile = await ApiClient.instance.get('/users/me');
      await SecureStorage.saveUserInfo(
        userId: profile.data['id'],
        userName: profile.data['full_name'],
      );
      state = state.copyWith(isLoggedIn: true, user: profile.data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> savePin(String pin) async {
    await SecureStorage.savePin(pin);
    state = state.copyWith(hasPin: true);
  }

  Future<bool> verifyPin(String pin) async {
    final saved = await SecureStorage.getPin();
    return saved == pin;
  }

  Future<void> logout() async {
    await SecureStorage.clearAll();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});