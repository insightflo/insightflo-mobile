import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/core/services/api_auth_service.dart';
import 'package:insightflo_app/core/utils/logger.dart';
import '../models/user_model.dart';

/// Abstract interface for authentication remote data source
/// 
/// Defines the contract for authentication operations with remote services.
/// This abstraction allows for easy testing and potential future changes
/// to the authentication provider.
abstract class AuthRemoteDataSource {
  /// Signs up a new user with email and password
  Future<UserModel> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  });

  /// Signs in an existing user with email and password
  Future<UserModel> signInWithPassword({
    required String email,
    required String password,
  });

  /// Signs out the current authenticated user
  Future<void> signOut();

  /// Retrieves the current authenticated user
  Future<UserModel?> getCurrentUser();

  /// Sends a password reset email to the specified email address
  Future<void> resetPassword({
    required String email,
  });

  /// Signs in a user with Google OAuth
  Future<UserModel> signInWithGoogle();

  /// Signs in a user with Apple OAuth
  Future<UserModel> signInWithApple();

  /// Sends email verification to the current user
  Future<void> sendEmailVerification();

  /// Confirms email verification with a token
  Future<void> verifyEmail({
    required String token,
  });

  /// Gets the stored authentication token
  Future<String?> getStoredToken();
}

/// Implementation of AuthRemoteDataSource using API-First architecture
/// 
/// This class provides authentication operations using HTTP API calls
/// to the InsightFlo API server. It handles API calls, response parsing, and
/// error conversion to application-specific exceptions.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiAuthService _apiAuthService;
  static const String _baseUrl = 'http://localhost:3000'; // TODO: Move to config

  /// Creates an instance of AuthRemoteDataSourceImpl
  /// 
  /// Uses API-First architecture pattern
  AuthRemoteDataSourceImpl() : _apiAuthService = ApiAuthService(httpClient: http.Client());

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      // API 기반 회원가입 - 현재는 register 엔드포인트가 없어서 임시로 anonymous 사용
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/anonymous'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': 'signup_${email}_${DateTime.now().millisecondsSinceEpoch}',
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return UserModel.fromJson(responseData['user']);
      } else {
        throw AuthException(
          message: 'Sign up failed',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw const NetworkException(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
      );
    } catch (e) {
      throw ServerException(
        message: 'Unexpected error during sign up: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<UserModel> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      // API 기반 로그인 - 현재는 login 엔드포인트가 없어서 임시로 anonymous 사용
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/anonymous'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': 'login_${email}_${DateTime.now().millisecondsSinceEpoch}',
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return UserModel.fromJson(responseData['user']);
      } else {
        throw AuthException(
          message: 'Sign in failed',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw const NetworkException(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
      );
    } catch (e) {
      throw ServerException(
        message: 'Unexpected error during sign in: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // API 기반 로그아웃 - 현재는 간단히 로컬 처리
      await _apiAuthService.signOut();
    } catch (e) {
      throw ServerException(
        message: 'Error during sign out: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      // 먼저 기존 세션 복원 시도
      await _apiAuthService.restoreSession();
      
      // 토큰이 없으면 익명 로그인 수행
      if (!_apiAuthService.isAuthenticated) {
        AppLogger.info('No existing session, performing anonymous login...');
        final authResult = await _apiAuthService.signInAnonymously();
        
        if (authResult.success) {
          AppLogger.info('Anonymous login successful');
          return UserModel.fromJson({
            'id': authResult.userId!,
            'email': authResult.email ?? '',
            'user_metadata': {'isAnonymous': authResult.isAnonymous},
            'email_confirmed_at': null,
            'created_at': DateTime.now().toIso8601String(),
          });
        } else {
          AppLogger.error('Anonymous login failed: ${authResult.error}');
          return null;
        }
      }
      
      // 기존 토큰이 있으면 익명 사용자 반환
      return UserModel.fromJson({
        'id': _apiAuthService.currentUserId ?? 'anonymous_user',
        'email': '',
        'user_metadata': {'isAnonymous': true},
        'email_confirmed_at': null,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      AppLogger.error('Error getting current user', e);
      throw ServerException(
        message: 'Error getting current user: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    // TODO: API 기반 비밀번호 리셋 구현
    throw UnimplementedError('Password reset not yet implemented for API-First architecture');
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    // TODO: API 기반 Google 로그인 구현
    throw UnimplementedError('Google sign in not yet implemented for API-First architecture');
  }

  @override
  Future<UserModel> signInWithApple() async {
    // TODO: API 기반 Apple 로그인 구현
    throw UnimplementedError('Apple sign in not yet implemented for API-First architecture');
  }

  @override
  Future<void> sendEmailVerification() async {
    // TODO: API 기반 이메일 인증 구현
    throw UnimplementedError('Email verification not yet implemented for API-First architecture');
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    // TODO: API 기반 이메일 인증 확인 구현
    throw UnimplementedError('Email verification confirmation not yet implemented for API-First architecture');
  }

  @override
  Future<String?> getStoredToken() async {
    try {
      // ApiAuthService의 currentToken을 통해 저장된 토큰 반환
      return _apiAuthService.currentToken;
    } catch (e) {
      throw ServerException(
        message: 'Error getting stored token: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}