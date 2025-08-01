import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:insightflo_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:insightflo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:insightflo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:insightflo_app/features/auth/domain/usecases/usecases.dart';
import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/core/services/deep_link_service.dart';
import 'package:insightflo_app/core/services/auth_flow_manager.dart';
import 'package:insightflo_app/features/auth/domain/entities/user.dart';
import 'package:insightflo_app/features/auth/data/models/user_model.dart';
import 'package:insightflo_app/core/errors/exceptions.dart';

// Generate mocks for API-First architecture testing
@GenerateMocks([
  FlutterSecureStorage,
  Connectivity,
  AuthRemoteDataSource,
])
import 'auth_integration_test.mocks.dart';

void main() {
  group('Authentication Integration Tests', () {
    late MockFlutterSecureStorage mockSecureStorage;
    late MockConnectivity mockConnectivity;
    late MockAuthRemoteDataSource mockRemoteDataSource;
    
    late AuthRepository authRepository;
    late AuthProvider authProvider;
    late DeepLinkService deepLinkService;
    late AuthFlowManager authFlowManager;

    setUp(() async {
      // Initialize mocks for API-First architecture
      mockSecureStorage = MockFlutterSecureStorage();
      mockConnectivity = MockConnectivity();
      mockRemoteDataSource = MockAuthRemoteDataSource();

      // Setup mock behaviors
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      // Create repository with API-First architecture
      authRepository = AuthRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        secureStorage: mockSecureStorage,
      );

      // Create use cases
      final signInUseCase = SignInUseCase(authRepository);
      final signUpUseCase = SignUpUseCase(authRepository);
      final signOutUseCase = SignOutUseCase(authRepository);
      final getCurrentUserUseCase = GetCurrentUserUseCase(authRepository);
      final resetPasswordUseCase = ResetPasswordUseCase(authRepository);
      final signInWithGoogleUseCase = SignInWithGoogleUseCase(authRepository);
      final signInWithAppleUseCase = SignInWithAppleUseCase(authRepository);
      final verifyEmailUseCase = VerifyEmailUseCase(authRepository);
      final sendEmailVerificationUseCase = SendEmailVerificationUseCase(authRepository);

      // Create auth provider
      authProvider = AuthProvider(
        signInUseCase: signInUseCase,
        signUpUseCase: signUpUseCase,
        signOutUseCase: signOutUseCase,
        getCurrentUserUseCase: getCurrentUserUseCase,
        resetPasswordUseCase: resetPasswordUseCase,
        signInWithGoogleUseCase: signInWithGoogleUseCase,
        signInWithAppleUseCase: signInWithAppleUseCase,
        verifyEmailUseCase: verifyEmailUseCase,
        // sendEmailVerificationUseCase: sendEmailVerificationUseCase, // \uad6c\ud604\ub418\uc9c0 \uc54a\uc544 \uc81c\uac70
      );

      // Create services
      deepLinkService = DeepLinkService();
      authFlowManager = AuthFlowManager(
        authProvider: authProvider,
        deepLinkService: deepLinkService,
      );
    });

    tearDown(() {
      authFlowManager.dispose();
      deepLinkService.dispose();
    });

    group('Email and Password Authentication', () {
      testWidgets('successful sign up flow', (WidgetTester tester) async {
        // Arrange
        final testUser = User(
          id: 'test-user-id',
          email: 'test@example.com',
          emailConfirmed: false,
          createdAt: DateTime.now(),
        );

        when(mockRemoteDataSource.signUp(
          email: anyNamed('email'),
          password: anyNamed('password'),
          data: anyNamed('data'),
        )).thenAnswer((_) async => UserModelFromEntity.fromEntity(testUser));

        // Act
        final result = await authProvider.signUp(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result, isTrue);
        expect(authProvider.isAuthenticated, isTrue);
        expect(authProvider.currentUser?.email, equals('test@example.com'));
        expect(authProvider.errorMessage, isNull);
      });

      testWidgets('successful sign in flow', (WidgetTester tester) async {
        // Arrange
        final testUser = User(
          id: 'test-user-id',
          email: 'test@example.com',
          emailConfirmed: true,
          createdAt: DateTime.now(),
        );

        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => UserModelFromEntity.fromEntity(testUser));

        // Act
        final result = await authProvider.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result, isTrue);
        expect(authProvider.isAuthenticated, isTrue);
        expect(authProvider.currentUser?.email, equals('test@example.com'));
        expect(authProvider.currentUser?.emailConfirmed, isTrue);
        expect(authProvider.errorMessage, isNull);
      });

      testWidgets('failed sign in with invalid credentials', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(const AuthException(message: 'Invalid login credentials'));

        // Act
        final result = await authProvider.signIn(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        // Assert
        expect(result, isFalse);
        expect(authProvider.isAuthenticated, isFalse);
        expect(authProvider.currentUser, isNull);
        expect(authProvider.errorMessage, contains('Invalid'));
      });

      testWidgets('successful sign out flow', (WidgetTester tester) async {
        // Arrange - first sign in
        final testUser = User(
          id: 'test-user-id',
          email: 'test@example.com',
          emailConfirmed: true,
          createdAt: DateTime.now(),
        );

        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => UserModelFromEntity.fromEntity(testUser));

        await authProvider.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(authProvider.isAuthenticated, isTrue);

        // Arrange - setup sign out
        when(mockRemoteDataSource.signOut()).thenAnswer((_) async {});

        // Act
        final result = await authProvider.signOut();

        // Assert
        expect(result, isTrue);
        expect(authProvider.isAuthenticated, isFalse);
        expect(authProvider.currentUser, isNull);
        expect(authProvider.errorMessage, isNull);
      });
    });

    group('Social Authentication', () {
      testWidgets('successful Google sign in flow', (WidgetTester tester) async {
        // Arrange
        final testUser = User(
          id: 'google-user-id',
          email: 'test@gmail.com',
          displayName: 'Test User',
          avatarUrl: 'https://example.com/avatar.jpg',
          emailConfirmed: true,
          createdAt: DateTime.now(),
        );

        when(mockRemoteDataSource.signInWithGoogle())
            .thenAnswer((_) async => UserModelFromEntity.fromEntity(testUser));

        // Act
        final result = await authProvider.signInWithGoogle();

        // Assert
        expect(result, isTrue);
        expect(authProvider.isAuthenticated, isTrue);
        expect(authProvider.currentUser?.email, equals('test@gmail.com'));
        expect(authProvider.currentUser?.displayName, equals('Test User'));
        expect(authProvider.currentUser?.emailConfirmed, isTrue);
        expect(authProvider.errorMessage, isNull);
      });

      testWidgets('successful Apple sign in flow', (WidgetTester tester) async {
        // Arrange
        final testUser = User(
          id: 'apple-user-id',
          email: 'test@privaterelay.appleid.com',
          displayName: 'Test User',
          emailConfirmed: true,
          createdAt: DateTime.now(),
        );

        when(mockRemoteDataSource.signInWithApple())
            .thenAnswer((_) async => UserModelFromEntity.fromEntity(testUser));

        // Act
        final result = await authProvider.signInWithApple();

        // Assert
        expect(result, isTrue);
        expect(authProvider.isAuthenticated, isTrue);
        expect(authProvider.currentUser?.email, equals('test@privaterelay.appleid.com'));
        expect(authProvider.currentUser?.emailConfirmed, isTrue);
        expect(authProvider.errorMessage, isNull);
      });

      testWidgets('failed Google sign in flow', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.signInWithGoogle())
            .thenThrow(const AuthException(message: 'Google sign-in was cancelled'));

        // Act
        final result = await authProvider.signInWithGoogle();

        // Assert
        expect(result, isFalse);
        expect(authProvider.isAuthenticated, isFalse);
        expect(authProvider.currentUser, isNull);
        expect(authProvider.errorMessage, contains('Google'));
      });
    });

    group('Email Verification', () {
      testWidgets('successful email verification', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.verifyEmail(
          token: anyNamed('token'),
        )).thenAnswer((_) async {});

        // Act
        final result = await authProvider.verifyEmail(token: 'valid-token');

        // Assert
        expect(result, isTrue);
        expect(authProvider.errorMessage, isNull);
      });

      testWidgets('failed email verification with invalid token', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.verifyEmail(
          token: anyNamed('token'),
        )).thenThrow(const AuthException(message: 'Invalid or expired verification token'));

        // Act
        final result = await authProvider.verifyEmail(token: 'invalid-token');

        // Assert
        expect(result, isFalse);
        expect(authProvider.errorMessage, contains('Invalid'));
      });

      testWidgets('successful send email verification', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.sendEmailVerification()).thenAnswer((_) async {});

        // Act
        final result = await authProvider.sendEmailVerification();

        // Assert
        expect(result, isTrue);
        expect(authProvider.errorMessage, isNull);
      });
    });

    group('Deep Link Handling', () {
      testWidgets('email verification deep link processing', (WidgetTester tester) async {
        // Arrange
        const testToken = 'test-verification-token';
        const testEmail = 'test@example.com';
        
        // Act
        await deepLinkService.testDeepLink(
          'insightflo://verify-email?token=$testToken&email=$testEmail'
        );

        // Assert
        await expectLater(
          deepLinkService.emailVerificationLinks,
          emits(isA<EmailVerificationLink>()),
        );
      });

      testWidgets('password reset deep link processing', (WidgetTester tester) async {
        // Arrange
        const testToken = 'test-reset-token';
        const testEmail = 'test@example.com';
        
        // Act
        await deepLinkService.testDeepLink(
          'insightflo://reset-password?token=$testToken&email=$testEmail'
        );

        // Assert
        await expectLater(
          deepLinkService.passwordResetLinks,
          emits(isA<PasswordResetLink>()),
        );
      });

      testWidgets('social auth callback deep link processing', (WidgetTester tester) async {
        // Arrange
        const testProvider = 'google';
        const testAccessToken = 'test-access-token';
        
        // Act
        await deepLinkService.testDeepLink(
          'insightflo://auth/callback?provider=$testProvider&access_token=$testAccessToken'
        );

        // Assert
        await expectLater(
          deepLinkService.socialAuthLinks,
          emits(isA<SocialAuthLink>()),
        );
      });
    });

    group('Session Recovery', () {
      testWidgets('successful session restoration', (WidgetTester tester) async {
        // Arrange
        final testUser = User(
          id: 'existing-user-id',
          email: 'existing@example.com',
          emailConfirmed: true,
          createdAt: DateTime.now(),
        );

        when(mockRemoteDataSource.getCurrentUser())
            .thenAnswer((_) async => UserModelFromEntity.fromEntity(testUser));

        // Act
        await authFlowManager.restoreSession();

        // Assert
        expect(authProvider.isAuthenticated, isTrue);
        expect(authProvider.currentUser?.email, equals('existing@example.com'));
      });

      testWidgets('session restoration with expired token', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.getCurrentUser())
            .thenThrow(const AuthException(message: 'JWT expired'));

        // Act
        await authFlowManager.restoreSession();

        // Assert
        expect(authProvider.isAuthenticated, isFalse);
        expect(authProvider.currentUser, isNull);
      });
    });

    group('Password Reset Flow', () {
      testWidgets('successful password reset request', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.resetPassword(
          email: anyNamed('email'),
        )).thenAnswer((_) async {});

        // Act
        final result = await authProvider.resetPassword(email: 'test@example.com');

        // Assert
        expect(result, isTrue);
        expect(authProvider.errorMessage, isNull);
      });

      testWidgets('failed password reset with invalid email', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.resetPassword(
          email: anyNamed('email'),
        )).thenThrow(const AuthException(
          message: 'Invalid email address',
          statusCode: 400,
        ));

        // Act
        final result = await authProvider.resetPassword(email: 'invalid-email');

        // Assert
        expect(result, isFalse);
        expect(authProvider.errorMessage, contains('Invalid'));
      });
    });

    group('Error Handling', () {
      testWidgets('network error handling', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(const NetworkException(
          message: 'No internet connection',
          statusCode: 0,
        ));

        // Act
        final result = await authProvider.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result, isFalse);
        expect(authProvider.errorMessage, contains('Network error'));
      });

      testWidgets('server error handling', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(const ServerException(
          message: 'Internal server error',
          statusCode: 500,
        ));

        // Act
        final result = await authProvider.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result, isFalse);
        expect(authProvider.errorMessage, contains('Server error'));
      });
    });

    group('Concurrent Operations', () {
      testWidgets('concurrent sign in attempts prevention', (WidgetTester tester) async {
        // Arrange
        when(mockRemoteDataSource.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 1));
          return UserModelFromEntity.fromEntity(User(
            id: 'test-id',
            email: 'test@example.com',
            emailConfirmed: true,
            createdAt: DateTime.now(),
          ));
        });

        // Act
        final future1 = authProvider.signIn(
          email: 'test@example.com',
          password: 'password123',
        );
        final future2 = authProvider.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        final results = await Future.wait([future1, future2]);

        // Assert
        expect(results.where((r) => r == true).length, equals(1));
        expect(results.where((r) => r == false).length, equals(1));
      });
    });
  });
}

/// Extension to convert User entity to UserModel for testing
extension UserModelFromEntity on UserModel {
  static UserModel fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      emailConfirmed: user.emailConfirmed,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      metadata: user.metadata,
    );
  }
}