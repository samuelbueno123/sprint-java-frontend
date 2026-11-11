import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:frontend/features/auth/domain/entities/auth_session.dart';
import 'package:frontend/features/auth/domain/entities/authenticated_user.dart';
import 'package:frontend/features/auth/domain/entities/user_role.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:frontend/features/auth/domain/usecases/sign_in_with_password.dart';
import 'package:frontend/features/auth/presentation/viewmodels/login_view_model.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FakeAuthRepository implements AuthRepository {
  AuthSession? mockSession;
  Exception? exceptionToThrow;
  final StreamController<GoogleSignInAccount?> _userStreamController =
      StreamController<GoogleSignInAccount?>.broadcast();

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _userStreamController.stream;

  @override
  Future<AuthSession> signInWithPassword(String email, String password) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSession!;
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSession!;
  }

  @override
  Future<AuthSession> signInWithIdToken(String idToken) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return mockSession!;
  }

  @override
  Future<void> signOutFromGoogle() async {}

  void dispose() {
    _userStreamController.close();
  }
}

void main() {
  late FakeAuthRepository fakeRepo;
  late LoginViewModel viewModel;

  const validSession = AuthSession(
    accessToken: 'valid-access',
    refreshToken: 'valid-refresh',
    user: AuthenticatedUser(
      id: '1',
      email: 'user@duolinfo.com',
      name: 'User One',
    ),
    profileType: UserRole.student,
  );

  setUp(() {
    fakeRepo = FakeAuthRepository();
    final signInWithPassword = SignInWithPassword(fakeRepo);
    final signInWithGoogle = SignInWithGoogle(fakeRepo);
    viewModel = LoginViewModel(signInWithPassword, signInWithGoogle);
  });

  tearDown(() {
    viewModel.dispose();
    fakeRepo.dispose();
  });

  group('LoginViewModel', () {
    test('starts with clean initial state', () {
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.session, isNull);
    });

    test('signInWithPassword succeeds and notifies listeners', () async {
      fakeRepo.mockSession = validSession;

      var notificationCount = 0;
      viewModel.addListener(() => notificationCount++);

      final future = viewModel.signInWithPassword(
        'user@duolinfo.com',
        'password123',
      );
      expect(viewModel.isLoading, isTrue);

      await future;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.session, equals(validSession));
      expect(
        notificationCount,
        greaterThanOrEqualTo(2),
      ); // start loading and finish loading
    });

    test(
      'signInWithPassword failure captures error message and resets loading',
      () async {
        fakeRepo.exceptionToThrow = const AuthException(
          'Credenciais inválidas.',
        );

        await viewModel.signInWithPassword('bad@duolinfo.com', 'wrong');

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.session, isNull);
        expect(viewModel.errorMessage, equals('Credenciais inválidas.'));
      },
    );

    test('signInWithGoogle succeeds and updates session', () async {
      fakeRepo.mockSession = validSession;

      await viewModel.signInWithGoogle();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.session, equals(validSession));
      expect(viewModel.errorMessage, isNull);
    });

    test(
      'signInWithGoogle failure captures error and clears session',
      () async {
        fakeRepo.exceptionToThrow = const AuthException(
          'Login com Google cancelado.',
        );

        await viewModel.signInWithGoogle();

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.session, isNull);
        expect(viewModel.errorMessage, equals('Login com Google cancelado.'));
      },
    );

    test('ignores second sign-in attempt if already authenticated', () async {
      fakeRepo.mockSession = validSession;
      await viewModel.signInWithPassword('user@duolinfo.com', 'pwd');

      // Attempt another sign-in
      fakeRepo.exceptionToThrow = const AuthException('Should not be called');
      await viewModel.signInWithPassword('other@duolinfo.com', 'pwd');

      // Still has first session
      expect(viewModel.session, equals(validSession));
    });
  });
}
