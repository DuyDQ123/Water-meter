import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isAdmin = false;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  String? get userEmail => _email;

  Future<String?> login(String email, String password) async {
    // Mock authentication for testing
    if (email.isNotEmpty && password.isNotEmpty) {
      _isAuthenticated = true;
      _email = email;
      _isAdmin = email.contains('admin');
      
      // Store admin status
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdmin', _isAdmin);
      
      notifyListeners();
      return null;
    }
    return 'Invalid email or password';
  }

  Future<String?> register(String email, String password) async {
    if (email.isNotEmpty && password.isNotEmpty) {
      _isAuthenticated = true;
      _email = email;
      notifyListeners();
      return null;
    }
    return 'Registration failed';
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _isAdmin = false;
    _email = null;
    notifyListeners();
  }
}