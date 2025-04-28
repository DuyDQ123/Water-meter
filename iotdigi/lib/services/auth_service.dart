import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isAdmin = false;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  String? get userEmail => _email;

  static const String baseUrl = 'http://192.168.1.159/iotdigi-main';

  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth_login.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return 'Server error: ${response.statusCode}';
      }

      Map<String, dynamic>? data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        return 'Invalid server response';
      }

      if (data == null || !data.containsKey('success')) {
        return 'Invalid response format';
      }

      if (data['success'] == true) {
        try {
          _isAuthenticated = true;
          _email = data['user']['email'];
          _isAdmin = data['user']['isAdmin'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAuthenticated', true);
          await prefs.setBool('isAdmin', _isAdmin);
          await prefs.setString('email', _email!);

          notifyListeners();
          return null;
        } catch (e) {
          return 'Error saving user data: $e';
        }
      }

      return data['error'] ?? 'Login failed';
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return 'Connection timed out. Please try again.';
      }
      return 'Network error. Please check your connection.';
    }
  }

  Future<String?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth_register.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _isAuthenticated = true;
        _email = data['user']['email'];
        _isAdmin = data['user']['isAdmin'];

        // Store user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', true);
        await prefs.setBool('isAdmin', _isAdmin);
        await prefs.setString('email', _email!);

        notifyListeners();
        return null;
      }

      return data['error'] ?? 'Registration failed';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _isAdmin = false;
    _email = null;

    // Clear stored user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  // Initialize auth state from stored preferences
  Future<void> initializeAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _isAdmin = prefs.getBool('isAdmin') ?? false;
    _email = prefs.getString('email');
    notifyListeners();
  }
}