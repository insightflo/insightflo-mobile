import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/features/auth/domain/entities/user.dart';
import 'package:insightflo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:insightflo_app/features/auth/domain/value_objects/email.dart';
import 'package:insightflo_app/features/auth/domain/value_objects/password.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

/// Implementation of AuthRepository following Clean Architecture principles
/// 
/// This repository acts as a bridge between the Domain layer and Data layer,
/// providing a clean interface for authentication operations using API-First architecture.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final FlutterSecureStorage _secureStorage;

  // Secure storage keys
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _accessTokenKey = 'auth_access_token';
  static const String _sessionExpiryKey = 'auth_session_expiry';
  static const String _userIdKey = 'auth_user_id';

  // Stream controllers for auth state management
  late final StreamController<User?> _authStateController;
  User? _currentUser;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required FlutterSecureStorage secureStorage,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorage = secureStorage,
        _authStateController = StreamController<User?>.broadcast() {
    _initializeAuthState();
  }

  /// Initializes authentication state management
  void _initializeAuthState() {
    // API-First architecture: 간소화된 초기화
    _initializeCurrentUser();
  }

  /// Initializes current user from existing session
  Future<void> _initializeCurrentUser() async {
    try {
      final currentUser = await getCurrentUser();
      currentUser.fold(
        (failure) => _currentUser = null,
        (user) {
          _currentUser = user;
          _authStateController.add(user);
        },
      );
    } catch (e) {
      _currentUser = null;
      _authStateController.add(null);
    }
  }

  @override
  Future<Either<Failure, User>> signUpWithEmailAndPassword({
    required Email email,
    required Password password,
    String? displayName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userModel = await _remoteDataSource.signUp(
        email: email.value,
        password: password.value,
        data: metadata,
      );

      final user = userModel as User;
      _currentUser = user;
      _authStateController.add(user);
      
      // Store tokens if available
      await _storeTokens(userModel);
      
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error during sign up: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithEmailAndPassword({
    required Email email,
    required Password password,
  }) async {
    try {
      final userModel = await _remoteDataSource.signInWithPassword(
        email: email.value,
        password: password.value,
      );

      final user = userModel as User;
      _currentUser = user;
      _authStateController.add(user);
      
      // Store tokens if available
      await _storeTokens(userModel);
      
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error during sign in: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      
      // Clear stored tokens
      await _clearTokens();
      
      _currentUser = null;
      _authStateController.add(null);
      
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error during sign out: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final userModel = await _remoteDataSource.getCurrentUser();
      
      if (userModel != null) {
        final user = userModel as User;
        _currentUser = user;
        return Right(user);
      } else {
        _currentUser = null;
        return const Right(null);
      }
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error getting current user: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail({required Email email}) async {
    try {
      await _remoteDataSource.resetPassword(email: email.value);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error during password reset: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    try {
      final userModel = await _remoteDataSource.signInWithGoogle();
      final user = userModel as User;
      
      _currentUser = user;
      _authStateController.add(user);
      await _storeTokens(userModel);
      
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error during Google sign in: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, User>> signInWithApple() async {
    try {
      final userModel = await _remoteDataSource.signInWithApple();
      final user = userModel as User;
      
      _currentUser = user;
      _authStateController.add(user);
      await _storeTokens(userModel);
      
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error during Apple sign in: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, void>> confirmEmailVerification({required String token}) async {
    try {
      await _remoteDataSource.verifyEmail(token: token);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error during email verification: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      await _remoteDataSource.sendEmailVerification();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error sending email verification: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, User>> signInAnonymously() async {
    try {
      // For now, use existing anonymous-like implementation
      // This could be enhanced to call a specific anonymous endpoint
      final userModel = await _remoteDataSource.signUp(
        email: 'anonymous@temp.com',
        password: 'temp_password',
        data: {'isAnonymous': true},
      );

      final user = userModel as User;
      _currentUser = user;
      _authStateController.add(user);
      
      // Store tokens if available
      await _storeTokens(userModel);
      
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error during anonymous sign in: ${e.toString()}',
        statusCode: 500,
      ));
    }
  }

  @override
  Future<Either<Failure, void>> updatePassword({
    required Password currentPassword,
    required Password newPassword,
  }) async {
    // TODO: Implement API-based password update
    return Left(ServerFailure(
      message: 'Password update not yet implemented for API-First architecture',
      statusCode: 501,
    ));
  }

  @override
  Future<Either<Failure, User>> updateProfile({
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    // TODO: Implement API-based profile update
    return Left(ServerFailure(
      message: 'Profile update not yet implemented for API-First architecture',
      statusCode: 501,
    ));
  }

  @override
  Future<Either<Failure, void>> refreshToken() async {
    // TODO: Implement API-based token refresh
    return Left(ServerFailure(
      message: 'Token refresh not yet implemented for API-First architecture',
      statusCode: 501,
    ));
  }

  @override
  Future<Either<Failure, void>> deleteAccount({
    required Password password,
  }) async {
    // TODO: Implement API-based account deletion
    return Left(ServerFailure(
      message: 'Account deletion not yet implemented for API-First architecture',
      statusCode: 501,
    ));
  }

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  User? get currentUserSync => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  /// Store authentication tokens securely
  Future<void> _storeTokens(UserModel userModel) async {
    try {
      // Store available tokens - UserModel may have token information
      if (userModel.id.isNotEmpty) {
        await _secureStorage.write(key: _userIdKey, value: userModel.id);
      }
      // Add token storage when available from API
    } catch (e) {
      // Token storage is best effort - don't fail auth if storage fails
    }
  }

  /// Clear stored authentication tokens
  Future<void> _clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _sessionExpiryKey);
      await _secureStorage.delete(key: _userIdKey);
    } catch (e) {
      // Token clearing is best effort
    }
  }

  /// Dispose of resources
  void dispose() {
    _authStateController.close();
  }
}