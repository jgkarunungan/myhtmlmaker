import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config_service.dart';

class TeacherAuthException implements Exception {
  final String message;
  final int? statusCode;

  const TeacherAuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Represents an active authenticated teacher session in memory.
class TeacherSession {
  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
  final bool isAuthorizedTeacher;

  const TeacherSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.isAuthorizedTeacher,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 60)));

  TeacherSession copyWith({
    String? uid,
    String? email,
    String? idToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool? isAuthorizedTeacher,
  }) {
    return TeacherSession(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      isAuthorizedTeacher: isAuthorizedTeacher ?? this.isAuthorizedTeacher,
    );
  }
}

/// Service managing teacher authentication and authorization via Firebase REST APIs.
///
/// Authentication tokens and passwords are kept purely in SESSION MEMORY.
class FirebaseTeacherAuthService {
  static final FirebaseTeacherAuthService instance = FirebaseTeacherAuthService();
  static const String _rememberedEmailKey = 'slm_remembered_teacher_email';

  final http.Client _client;
  final FirebaseConfigService _firebaseConfig;

  TeacherSession? _currentSession;

  FirebaseTeacherAuthService({
    http.Client? client,
    FirebaseConfigService? firebaseConfig,
  })  : _client = client ?? http.Client(),
        _firebaseConfig = firebaseConfig ?? const FirebaseConfigService();

  TeacherSession? get currentSession => _currentSession;
  bool get isSignedIn => _currentSession != null;
  bool get isAuthorizedTeacher => _currentSession?.isAuthorizedTeacher ?? false;

  /// Loads remembered teacher email from SharedPreferences (convenience setting only).
  Future<String> getRememberedEmail({SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    return prefs.getString(_rememberedEmailKey) ?? '';
  }

  /// Sets or clears remembered teacher email.
  Future<void> setRememberedEmail(String email, {SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_rememberedEmailKey);
    } else {
      await prefs.setString(_rememberedEmailKey, trimmed);
    }
  }

  /// Authenticates a teacher using Firebase Identity Toolkit REST API and checks authorization.
  Future<TeacherSession> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberEmail = true,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw const TeacherAuthException('Email and password cannot be empty.');
    }

    final String apiKey = _firebaseConfig.apiKey;
    final String url =
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey';

    http.Response response;
    try {
      response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': cleanPassword,
          'returnSecureToken': true,
        }),
      );
    } catch (e) {
      throw TeacherAuthException('Network error during authentication: ${e.toString()}');
    }

    if (response.statusCode != 200) {
      String errorMsg = 'Authentication failed (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        final err = decoded['error']?['message']?.toString();
        if (err == 'EMAIL_NOT_FOUND' || err == 'INVALID_PASSWORD' || err == 'INVALID_LOGIN_CREDENTIALS') {
          errorMsg = 'Invalid teacher email or password.';
        } else if (err != null) {
          errorMsg = err;
        }
      } catch (_) {}
      throw TeacherAuthException(errorMsg, statusCode: response.statusCode);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final uid = decoded['localId']?.toString() ?? '';
    final idToken = decoded['idToken']?.toString() ?? '';
    final refreshToken = decoded['refreshToken']?.toString() ?? '';
    final expiresInStr = decoded['expiresIn']?.toString() ?? '3600';
    final expiresInSec = int.tryParse(expiresInStr) ?? 3600;

    final expiresAt = DateTime.now().add(Duration(seconds: expiresInSec));

    if (rememberEmail) {
      await setRememberedEmail(cleanEmail);
    }

    final tempSession = TeacherSession(
      uid: uid,
      email: cleanEmail,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      isAuthorizedTeacher: false,
    );

    // Verify teacher authorization in teachers/{uid}
    final isAuth = await _checkTeacherAuthorization(tempSession);
    if (!isAuth) {
      _currentSession = null;
      throw const TeacherAuthException(
        'Your Firebase account is authenticated but is not authorized as a teacher.',
        statusCode: 403,
      );
    }

    _currentSession = tempSession.copyWith(isAuthorizedTeacher: true);
    return _currentSession!;
  }

  /// Verifies if `teachers/{uid}` exists and contains `role == "teacher"` and `active == true`.
  Future<bool> _checkTeacherAuthorization(TeacherSession session) async {
    final String projectId = _firebaseConfig.projectId;
    final String url =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/teachers/${session.uid}';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${session.idToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = decoded['fields'] as Map<String, dynamic>?;
      if (fields == null) return false;

      final roleStr = fields['role']?['stringValue']?.toString();
      final activeBool = fields['active']?['booleanValue'] as bool? ?? false;

      return roleStr == 'teacher' && activeBool;
    } catch (_) {
      return false;
    }
  }

  /// Returns a valid ID token, performing ONE token refresh if expired.
  Future<String> getValidIdToken() async {
    if (_currentSession == null) {
      throw const TeacherAuthException('Teacher is not signed in.');
    }

    if (!_currentSession!.isExpired) {
      return _currentSession!.idToken;
    }

    // Token is expired, attempt ONE refresh
    try {
      final refreshedSession = await _refreshIdToken(_currentSession!);
      _currentSession = refreshedSession;
      return _currentSession!.idToken;
    } catch (e) {
      signOut();
      throw const TeacherAuthException('Session expired. Please sign in again.');
    }
  }

  /// Refreshes the ID token using the refresh token via Secure Token REST API.
  Future<TeacherSession> _refreshIdToken(TeacherSession session) async {
    final String apiKey = _firebaseConfig.apiKey;
    final String url = 'https://securetoken.googleapis.com/v1/token?key=$apiKey';

    final response = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(session.refreshToken)}',
    );

    if (response.statusCode != 200) {
      throw TeacherAuthException('Failed to refresh token (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final newIdToken = decoded['id_token']?.toString() ?? '';
    final newRefreshToken = decoded['refresh_token']?.toString() ?? session.refreshToken;
    final expiresInStr = decoded['expires_in']?.toString() ?? '3600';
    final expiresInSec = int.tryParse(expiresInStr) ?? 3600;

    return session.copyWith(
      idToken: newIdToken,
      refreshToken: newRefreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSec)),
    );
  }

  /// Clears the active teacher session from memory.
  void signOut() {
    _currentSession = null;
  }
}
