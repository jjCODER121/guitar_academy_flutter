import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AppUser {
  const AppUser({required this.id, required this.email, this.name});

  final String id;
  final String email;
  final String? name;

  /// Буква для аватара.
  String get initial => (name ?? email).substring(0, 1).toUpperCase();
}

class InvalidCodeException implements Exception {
  const InvalidCodeException();
}

/// Письмо с кодом не ушло (лимит почты, нет сети).
class OtpSendException implements Exception {
  const OtpSendException(this.message);

  final String message;
}

/// Длина кода из письма.
const otpLength = 6;

/// Вход без пароля: код на email (Google — позже, нужна настройка в Google Cloud).
abstract interface class AuthRepository {
  AppUser? restoreSession();
  bool get googleEnabled;
  Future<void> requestOtp(String email);
  Future<AppUser> verifyOtp(String email, String code);
  Future<AppUser> signInWithGoogle();
  Future<void> signOut();
}

/// Supabase Auth: письмо с кодом, затем проверка кода. Аккаунт создаётся сам
/// при первом входе; сессия хранится и обновляется supabase_flutter.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final sb.SupabaseClient _client;

  static AppUser? _toUser(sb.User? u) =>
      u == null ? null : AppUser(id: u.id, email: u.email ?? '');

  @override
  AppUser? restoreSession() => _toUser(_client.auth.currentUser);

  @override
  bool get googleEnabled => false;

  @override
  Future<void> requestOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
    } on sb.AuthException catch (e) {
      throw OtpSendException(e.message);
    }
  }

  @override
  Future<AppUser> verifyOtp(String email, String code) async {
    try {
      final res = await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: sb.OtpType.email,
      );
      return _toUser(res.user) ?? (throw const InvalidCodeException());
    } on sb.AuthException {
      throw const InvalidCodeException();
    }
  }

  @override
  Future<AppUser> signInWithGoogle() =>
      throw UnsupportedError('Вход через Google ещё не настроен');

  @override
  Future<void> signOut() => _client.auth.signOut();
}

/// Для тестов: любой код из [otpLength] цифр подходит, «Google» входит под демо-адресом.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(
    this._prefs, {
    this.latency = const Duration(milliseconds: 600),
  });

  static const _key = 'mock_session_email';
  final SharedPreferences _prefs;
  final Duration latency;

  static AppUser _user(String email) =>
      AppUser(id: 'mock-$email', email: email);

  @override
  AppUser? restoreSession() {
    final email = _prefs.getString(_key);
    return email == null ? null : _user(email);
  }

  @override
  bool get googleEnabled => true;

  @override
  Future<void> requestOtp(String email) => Future<void>.delayed(latency);

  @override
  Future<AppUser> verifyOtp(String email, String code) async {
    await Future<void>.delayed(latency);
    if (!RegExp('^\\d{$otpLength}\$').hasMatch(code)) {
      throw const InvalidCodeException();
    }
    await _prefs.setString(_key, email);
    return _user(email);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await Future<void>.delayed(latency);
    const email = 'student@gmail.com';
    await _prefs.setString(_key, email);
    return _user(email);
  }

  @override
  Future<void> signOut() => _prefs.remove(_key);
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(sb.Supabase.instance.client),
);

/// Текущий пользователь; null — гость.
final authProvider = NotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

class AuthController extends Notifier<AppUser?> {
  @override
  AppUser? build() => ref.watch(authRepositoryProvider).restoreSession();

  Future<void> requestOtp(String email) =>
      ref.read(authRepositoryProvider).requestOtp(email);

  Future<void> verifyOtp(String email, String code) async {
    state = await ref.read(authRepositoryProvider).verifyOtp(email, code);
  }

  Future<void> signInWithGoogle() async {
    state = await ref.read(authRepositoryProvider).signInWithGoogle();
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

bool isValidEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
