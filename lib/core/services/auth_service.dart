import 'package:flutter/material.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  
  String? _currentUserName;
  String? _currentUserEmail;
  bool _isAdmin = false;

  AuthService._init();

  String get currentUserName => _currentUserName ?? 'Anonymous_User';
  String get currentUserEmail => _currentUserEmail ?? 'unknown@mail.com';
  bool get isAdmin => _isAdmin;

  void loginUser(String name, String email, {bool admin = false}) {
    _currentUserName = name;
    _currentUserEmail = email;
    _isAdmin = admin;
  }

  void logout() {
    _currentUserName = null;
    _currentUserEmail = null;
    _isAdmin = false;
  }
}
