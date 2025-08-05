import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/core/utils/logger.dart';

/// API 기반 인증 서비스
/// Supabase를 직접 사용하지 않고, API 서버를 통해 인증 처리
class ApiAuthService {
  final http.Client httpClient;
  final String apiBaseUrl;

  // 토큰 캐시
  String? _cachedToken;
  String? _cachedUserId;
  DateTime? _tokenExpiry;

  ApiAuthService({
    required this.httpClient,
    this.apiBaseUrl = 'http://localhost:3000', // API 서버 주소
  });

  /// 현재 사용자가 인증되었는지 확인
  bool get isAuthenticated => _cachedToken != null && !_isTokenExpired();

  /// 현재 인증된 사용자 ID
  String? get currentUserId => _cachedUserId;

  /// 현재 JWT 토큰
  String? get currentToken => _cachedToken;

  /// 토큰이 만료되었는지 확인
  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!);
  }

  /// 앱 시작 시 저장된 토큰 복원
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');
      final expiryString = prefs.getString('token_expiry');

      if (token != null && userId != null && expiryString != null) {
        final expiry = DateTime.parse(expiryString);

        if (DateTime.now().isBefore(expiry)) {
          _cachedToken = token;
          _cachedUserId = userId;
          _tokenExpiry = expiry;

          AppLogger.info('Session restored for user: $userId');
        } else {
          AppLogger.warning('Stored token expired, clearing session');
          await clearSession();
        }
      }
    } catch (e) {
      AppLogger.error('Failed to restore session', e);
    }
  }

  /// 익명 사용자로 로그인
  Future<AuthResult> signInAnonymously() async {
    try {
      AppLogger.info('Signing in anonymously...');

      final response = await httpClient
          .post(
            Uri.parse('$apiBaseUrl/api/auth/anonymous'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      AppLogger.debug('Anonymous login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          final user = data['user'] as Map<String, dynamic>;
          final token = data['token'] as String;
          final expiresIn = data['expiresIn'] as int;

          // 토큰 캐시 및 저장
          await _cacheTokenAndUser(
            token: token,
            userId: user['id'] as String,
            expiresIn: expiresIn,
          );

          return AuthResult.success(
            userId: user['id'] as String,
            isAnonymous: true,
            token: token,
          );
        } else {
          throw ServerException(message: 'Invalid response format', statusCode: response.statusCode);
        }
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw ServerException(message: errorData['message'] ?? 'Anonymous login failed', statusCode: response.statusCode);
      }
    } catch (e) {
      AppLogger.error('Anonymous login error', e);
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to sign in anonymously: $e', statusCode: 500);
    }
  }

  /// 이메일/비밀번호로 로그인
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('Signing in with email: $email');

      final response = await httpClient
          .post(
            Uri.parse('$apiBaseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      AppLogger.debug('Email login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          final user = data['user'] as Map<String, dynamic>;
          final token = data['token'] as String;
          final expiresIn = data['expiresIn'] as int;

          // 토큰 캐시 및 저장
          await _cacheTokenAndUser(
            token: token,
            userId: user['id'] as String,
            expiresIn: expiresIn,
          );

          return AuthResult.success(
            userId: user['id'] as String,
            email: user['email'] as String,
            isAnonymous: false,
            token: token,
          );
        } else {
          throw ServerException(message: 'Invalid response format', statusCode: response.statusCode);
        }
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw ServerException(message: errorData['message'] ?? 'Login failed', statusCode: response.statusCode);
      }
    } catch (e) {
      AppLogger.error('Email login error', e);
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to sign in: $e', statusCode: 500);
    }
  }

  /// 회원가입
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      AppLogger.info('Signing up with email: $email');

      final response = await httpClient
          .post(
            Uri.parse('$apiBaseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': email,
              'password': password,
              'name': name,
            }),
          )
          .timeout(const Duration(seconds: 10));

      AppLogger.debug('Registration response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['success'] == true) {
          final user = data['user'] as Map<String, dynamic>;
          final token = data['token'] as String;
          final expiresIn = data['expiresIn'] as int;

          // 토큰 캐시 및 저장
          await _cacheTokenAndUser(
            token: token,
            userId: user['id'] as String,
            expiresIn: expiresIn,
          );

          return AuthResult.success(
            userId: user['id'] as String,
            email: user['email'] as String,
            isAnonymous: false,
            token: token,
            message: data['message'] as String?,
          );
        } else {
          throw ServerException(message: 'Invalid response format', statusCode: response.statusCode);
        }
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: errorData['message'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      AppLogger.error('Registration error', e);
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to sign up: $e', statusCode: 500);
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await clearSession();
    AppLogger.info('User signed out');
  }

  /// 세션 정보 캐시 및 저장
  Future<void> _cacheTokenAndUser({
    required String token,
    required String userId,
    required int expiresIn,
  }) async {
    final expiry = DateTime.now().add(Duration(seconds: expiresIn));

    _cachedToken = token;
    _cachedUserId = userId;
    _tokenExpiry = expiry;

    // SharedPreferences에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', userId);
    await prefs.setString('token_expiry', expiry.toIso8601String());

    AppLogger.debug('Token cached for user: $userId, expires: $expiry');
  }

  /// 세션 정보 삭제
  Future<void> clearSession() async {
    _cachedToken = null;
    _cachedUserId = null;
    _tokenExpiry = null;

    // SharedPreferences에서 삭제
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('token_expiry');
  }

  /// HTTP 요청에 사용할 인증 헤더 생성
  Map<String, String> getAuthHeaders() {
    // 토큰이 없거나 만료된 경우 Anonymous 토큰을 자동 생성
    if (_cachedToken == null || _isTokenExpired()) {
      AppLogger.info('No token available, attempting anonymous authentication');
      try {
        // Anonymous 토큰을 동기적으로 생성할 수 없으므로 기본 헤더 반환
        return {'Content-Type': 'application/json'};
      } catch (e) {
        AppLogger.warning(
          'Failed to get anonymous token, using default headers',
          e,
        );
        return {'Content-Type': 'application/json'};
      }
    }

    return {
      'Authorization': 'Bearer $_cachedToken',
      'Content-Type': 'application/json',
    };
  }

  /// 토큰 갱신 (필요시 구현)
  Future<void> refreshToken() async {
    // TODO: 토큰 갱신 로직 구현
    throw UnimplementedError('Token refresh not implemented yet');
  }
}

/// 인증 결과 클래스
class AuthResult {
  final bool success;
  final String? userId;
  final String? email;
  final bool isAnonymous;
  final String? token;
  final String? error;
  final String? message;

  const AuthResult._({
    required this.success,
    this.userId,
    this.email,
    this.isAnonymous = false,
    this.token,
    this.error,
    this.message,
  });

  factory AuthResult.success({
    required String userId,
    String? email,
    bool isAnonymous = false,
    String? token,
    String? message,
  }) {
    return AuthResult._(
      success: true,
      userId: userId,
      email: email,
      isAnonymous: isAnonymous,
      token: token,
      message: message,
    );
  }

  factory AuthResult.failure({required String error, String? message}) {
    return AuthResult._(success: false, error: error, message: message);
  }
}
