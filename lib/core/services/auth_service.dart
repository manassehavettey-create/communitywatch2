import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';

class AuthService {
  static final AuthService instance = AuthService._init();

  String? _currentUserName;
  String? _currentUserEmail;
  String? _sessionToken;
  bool _isAdmin = false;
  Map<String, dynamic>? _pendingDossier;

  AuthService._init();

  Future<void> initializeSession() async {
    final session = await DatabaseService.instance.getActiveSession();
    if (session != null) {
      _currentUserName = session['username'];
      _currentUserEmail = session['email'];
      _sessionToken = session['session_token'];
      _isAdmin = session['is_admin'] == 1;
      debugPrint("📡 [SESSION] Unit $_currentUserName Linked.");
    }
  }

  String get currentUserName => _currentUserName ?? 'Unit_Detached';
  String get currentUserEmail => _currentUserEmail ?? 'unknown@mail.com';
  String? get sessionToken => _sessionToken;
  bool get isAdmin => _isAdmin;

  String getBaseUrl() {
    return 'https://communitywatch2.onrender.com/api';
  }

  Map<String, String> getSecureHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
    };
  }

  Future<Map<String, dynamic>> secureLogin(
    String email,
    String password,
  ) async {
    try {
      final url = Uri.parse('${getBaseUrl()}/login');
      debugPrint("📡 [NETWORK] Attempting Link: $url");

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _pendingDossier = data['user'];
        _sessionToken = data['token'];
        _isAdmin = data['user']['is_admin'] == 1;
        _currentUserName = data['user']['username'];
        _currentUserEmail = data['user']['email'];

        if (_isAdmin)
          await DatabaseService.instance.saveSession(
            _pendingDossier!,
            _sessionToken,
          );
        return {'success': true};
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'LOGIN_FAILED',
      };
    } catch (e) {
      debugPrint("❌ [NETWORK_ERROR]: $e");
      return {'success': false, 'message': 'LINK_OFFLINE: $e'};
    }
  }

  Future<Map<String, dynamic>> secureRegister(
    Map<String, dynamic> userData,
    Map<String, String?> captures,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${getBaseUrl()}/register'),
      );
      userData.forEach((key, value) => request.fields[key] = value.toString());
      if (!kIsWeb) {
        if (captures['CENTER'] != null)
          request.files.add(
            await http.MultipartFile.fromPath(
              'face_center',
              captures['CENTER']!,
            ),
          );
      }
      var res = await request.send();
      if (res.statusCode == 200) {
        _pendingDossier = userData;
        return {'success': true};
      }
      return {'success': false, 'message': 'FAIL'};
    } catch (e) {
      return {'success': false, 'message': 'ERROR'};
    }
  }

  Future<bool> verifyOtpAndEstablishLink(String identifier, String code) async {
    try {
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': identifier, 'code': code}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sessionToken = data['token'];
        if (_pendingDossier != null) {
          _currentUserName = _pendingDossier!['username'];
          _currentUserEmail = _pendingDossier!['email'];
          _isAdmin = _pendingDossier!['is_admin'] == 1;
          await DatabaseService.instance.saveSession(
            _pendingDossier!,
            _sessionToken,
          );
          _pendingDossier = null;
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> syncLocation(double lat, double lng) async {
    if (_sessionToken == null) return;
    try {
      await http.post(
        Uri.parse('${getBaseUrl()}/update-location'),
        headers: getSecureHeaders(),
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> fetchAllActiveNodes() async {
    try {
      final res = await http.get(
        Uri.parse('${getBaseUrl()}/nodes'),
        headers: getSecureHeaders(),
      );
      if (res.statusCode == 200)
        return List<Map<String, dynamic>>.from(jsonDecode(res.body)['nodes']);
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> initiateForgotPassword(String phone) async {
    try {
      final res = await http.post(
        Uri.parse('${getBaseUrl()}/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'ERROR'};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String id, String pass) async {
    try {
      final res = await http.post(
        Uri.parse('${getBaseUrl()}/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': id, 'newPassword': pass}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'ERROR'};
    }
  }

  Future<bool> requestBiometricVerification() async {
    try {
      final res = await http
          .post(
            Uri.parse('${getBaseUrl()}/biometric-verify'),
            headers: getSecureHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> updatedData) async {
    try {
      final res = await http.post(
        Uri.parse('${getBaseUrl()}/update-profile'),
        headers: getSecureHeaders(),
        body: jsonEncode(updatedData),
      );
      if (res.statusCode == 200) {
        if (updatedData.containsKey('username')) {
          _currentUserName = updatedData['username'];
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void logout() async {
    if (_sessionToken != null) {
      try {
        await http.post(
          Uri.parse('${getBaseUrl()}/logout'),
          headers: getSecureHeaders(),
        );
      } catch (_) {}
    }
    _currentUserName = null;
    _currentUserEmail = null;
    _sessionToken = null;
    _isAdmin = false;
  }
}
