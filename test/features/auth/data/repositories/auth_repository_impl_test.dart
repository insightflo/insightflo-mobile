import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:insightflo_app/features/auth/data/models/user_model.dart';
import 'package:insightflo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:insightflo_app/features/auth/domain/entities/user.dart';
import 'package:insightflo_app/features/auth/domain/value_objects/email.dart';
import 'package:insightflo_app/features/auth/domain/value_objects/password.dart';

// Generate mocks for API-First architecture
@GenerateMocks([
  AuthRemoteDataSource,
  FlutterSecureStorage,
])
import 'auth_repository_impl_test.mocks.dart';

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockSecureStorage = MockFlutterSecureStorage();

    // API-First architecture - no Supabase client needed
    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      secureStorage: mockSecureStorage,
    );
  });

  tearDown(() {
    repository.dispose();
  });

  group('AuthRepositoryImpl', () {
    final testEmail = Email.fromTrustedSource('test@example.com');
    final testPassword = Password.fromTrustedSource('password123');
    final testUserModel = UserModel.test(
      id: 'test-id',
      email: 'test@example.com',
      displayName: 'Test User',
    );

    group('signUpWithEmailAndPassword', () {
      test('should return User when sign up is successful', () async {
        // Arrange
        when(mockRemoteDataSource.signUp(
          email: anyNamed('email'),
          password: anyNamed('password'),
          data: anyNamed('data'),
        )).thenAnswer((_) async => testUserModel);

        // Act
        final result = await repository.signUpWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
          metadata: {'display_name': 'Test User'},
        );

        // Assert
        expect(result, isA<Right<Failure, User>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (user) => expect(user.email, equals('test@example.com')),
        );
        verify(mockRemoteDataSource.signUp(
          email: testEmail.value,
          password: testPassword.value,
          data: {'display_name': 'Test User'},
        )).called(1);
      });

      test('should return AuthFailure when sign up fails with AuthException', () async {
        // Arrange
        when(mockRemoteDataSource.signUp(
          email: anyNamed('email'),
          password: anyNamed('password'),
          data: anyNamed('data'),
        )).thenThrow(const AuthException(
          message: 'Email already exists',
          statusCode: 409,
        ));

        // Act
        final result = await repository.signUpWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.fold(
          (failure) {
            expect(failure, isA<AuthFailure>());
            expect(failure.message, equals('Email already exists'));
            expect(failure.statusCode, equals(409));
          },
          (user) => fail('Expected Left but got Right: $user'),
        );
      });

      test('should return NetworkFailure when sign up fails with NetworkException', () async {
        // Arrange
        when(mockRemoteDataSource.signUp(
          email: anyNamed('email'),
          password: anyNamed('password'),
          data: anyNamed('data'),
        )).thenThrow(const NetworkException(
          message: 'No internet connection',
          statusCode: 0,
        ));

        // Act
        final result = await repository.signUpWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.fold(
          (failure) {
            expect(failure, isA<NetworkFailure>());
            expect(failure.message, equals('No internet connection'));
          },
          (user) => fail('Expected Left but got Right: $user'),
        );
      });
    });

    group('signInWithEmailAndPassword', () {
      test('should return User when sign in is successful', () async {
        // Arrange
        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => testUserModel);

        // Act
        final result = await repository.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        // Assert
        expect(result, isA<Right<Failure, User>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (user) => expect(user.email, equals('test@example.com')),
        );
        verify(mockRemoteDataSource.signInWithPassword(
          email: testEmail.value,
          password: testPassword.value,
        )).called(1);
      });

      test('should return specific AuthFailure for invalid credentials', () async {
        // Arrange
        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(const AuthException(
          message: 'Invalid login credentials',
          statusCode: 401,
        ));

        // Act
        final result = await repository.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.fold(
          (failure) {
            expect(failure, isA<AuthFailure>());
            expect(failure.statusCode, equals(401));
          },
          (user) => fail('Expected Left but got Right: $user'),
        );
      });
    });

    group('signInAnonymously', () {
      test('should return User when anonymous sign in is successful', () async {
        // Arrange
        when(mockRemoteDataSource.signUp(
          email: anyNamed('email'),
          password: anyNamed('password'),
          data: anyNamed('data'),
        )).thenAnswer((_) async => testUserModel);

        // Act
        final result = await repository.signInAnonymously();

        // Assert
        expect(result, isA<Right<Failure, User>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (user) => expect(user.email, equals('test@example.com')),
        );
        verify(mockRemoteDataSource.signUp(
          email: 'anonymous@temp.com',
          password: 'temp_password',
          data: {'isAnonymous': true},
        )).called(1);
      });

      test('should return AuthFailure when anonymous sign in fails', () async {
        // Arrange
        when(mockRemoteDataSource.signUp(
          email: anyNamed('email'),
          password: anyNamed('password'),
          data: anyNamed('data'),
        )).thenThrow(const AuthException(
          message: 'Anonymous sign in failed',
          statusCode: 500,
        ));

        // Act
        final result = await repository.signInAnonymously();

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.fold(
          (failure) {
            expect(failure, isA<AuthFailure>());
            expect(failure.message, equals('Anonymous sign in failed'));
          },
          (user) => fail('Expected Left but got Right: $user'),
        );
      });
    });

    group('signOut', () {
      test('should return success when sign out completes', () async {
        // Arrange
        when(mockRemoteDataSource.signOut()).thenAnswer((_) async {});
        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        // Act
        final result = await repository.signOut();

        // Assert
        expect(result, isA<Right<Failure, void>>());
        verify(mockRemoteDataSource.signOut()).called(1);
        verify(mockSecureStorage.delete(key: 'auth_access_token')).called(1);
        verify(mockSecureStorage.delete(key: 'auth_refresh_token')).called(1);
        verify(mockSecureStorage.delete(key: 'auth_session_expiry')).called(1);
        verify(mockSecureStorage.delete(key: 'auth_user_id')).called(1);
      });

      test('should return failure when sign out fails', () async {
        // Arrange
        when(mockRemoteDataSource.signOut()).thenThrow(
          const ServerException(message: 'Server error', statusCode: 500),
        );

        // Act
        final result = await repository.signOut();

        // Assert
        expect(result, isA<Left<Failure, void>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, equals('Server error'));
          },
          (_) => fail('Expected Left but got Right'),
        );
      });
    });

    group('getCurrentUser', () {
      test('should return null when no user is authenticated', () async {
        // Arrange
        when(mockSecureStorage.read(key: 'auth_session_expiry'))
            .thenAnswer((_) async => null);
        when(mockRemoteDataSource.getCurrentUser())
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result, isA<Right<Failure, User?>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (user) => expect(user, isNull),
        );
      });

      test('should return User when user is authenticated', () async {
        // Arrange
        final futureExpiry = DateTime.now().add(const Duration(hours: 1))
            .millisecondsSinceEpoch ~/ 1000;
        when(mockSecureStorage.read(key: 'auth_session_expiry'))
            .thenAnswer((_) async => futureExpiry.toString());
        when(mockRemoteDataSource.getCurrentUser())
            .thenAnswer((_) async => testUserModel);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result, isA<Right<Failure, User?>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (user) {
            expect(user, isNotNull);
            expect(user!.email, equals('test@example.com'));
          },
        );
      });
    });

    group('sendPasswordResetEmail', () {
      test('should return success when password reset email is sent', () async {
        // Arrange
        when(mockRemoteDataSource.resetPassword(email: testEmail.value))
            .thenAnswer((_) async {});

        // Act
        final result = await repository.sendPasswordResetEmail(email: testEmail);

        // Assert
        expect(result, isA<Right<Failure, void>>());
        verify(mockRemoteDataSource.resetPassword(
          email: testEmail.value,
        )).called(1);
      });
    });

    // API-First architecture - these methods return UnimplementedError for now
    group('updatePassword', () {
      test('should return ServerFailure with not implemented message', () async {
        // Act
        final result = await repository.updatePassword(
          currentPassword: testPassword,
          newPassword: Password.fromTrustedSource('newpassword123'),
        );

        // Assert
        expect(result, isA<Left<Failure, void>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, contains('not yet implemented'));
            expect(failure.statusCode, equals(501));
          },
          (_) => fail('Expected Left but got Right'),
        );
      });
    });

    group('updateProfile', () {
      test('should return ServerFailure with not implemented message', () async {
        // Act
        final result = await repository.updateProfile(
          displayName: 'New Name',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, contains('not yet implemented'));
            expect(failure.statusCode, equals(501));
          },
          (_) => fail('Expected Left but got Right'),
        );
      });
    });

    group('refreshToken', () {
      test('should return ServerFailure with not implemented message', () async {
        // Act
        final result = await repository.refreshToken();

        // Assert
        expect(result, isA<Left<Failure, void>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, contains('not yet implemented'));
            expect(failure.statusCode, equals(501));
          },
          (_) => fail('Expected Left but got Right'),
        );
      });
    });

    group('deleteAccount', () {
      test('should return ServerFailure with not implemented message', () async {
        // Act
        final result = await repository.deleteAccount(password: testPassword);

        // Assert
        expect(result, isA<Left<Failure, void>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, contains('not yet implemented'));
            expect(failure.statusCode, equals(501));
          },
          (_) => fail('Expected Left but got Right'),
        );
      });
    });

    group('error mapping', () {
      test('should map AuthException to appropriate specific failures', () async {
        // Test invalid credentials
        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(const AuthException(
          message: 'Invalid login credentials',
          statusCode: 401,
        ));

        final result = await repository.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<AuthFailure>()),
          (_) => fail('Expected failure'),
        );
      });

      test('should map email already exists error to EmailAlreadyInUseFailure', () async {
        when(mockRemoteDataSource.signUp(
          email: anyNamed('email'),
          password: anyNamed('password'),
          data: anyNamed('data'),
        )).thenThrow(const AuthException(
          message: 'User already registered',
          statusCode: 409,
        ));

        final result = await repository.signUpWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<AuthFailure>()),
          (_) => fail('Expected failure'),
        );
      });
    });

    group('authentication state management', () {
      test('should provide authentication state stream', () {
        expect(repository.authStateChanges, isA<Stream<User?>>());
      });

      test('should return correct authentication status', () {
        expect(repository.isAuthenticated, isFalse);
      });

      test('should return null for current user when not authenticated', () {
        expect(repository.currentUserSync, isNull);
      });
    });
  });
}