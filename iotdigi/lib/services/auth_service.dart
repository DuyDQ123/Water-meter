import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class AuthService with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isAdmin = false;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;
  String? get userEmail => _email;

  // Match the server IP used in other files
  static const String baseUrl = 'http://192.168.137.1/iotdigi-main';

  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth_login.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        debugPrint('Server error with status code: ${response.statusCode}');
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
    } on TimeoutException catch (_) {
      return 'Connection timed out. Please check your network and try again.';
    } catch (e) {
      return 'Network error: ${e.toString()}';
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
      ).timeout(
        const Duration(seconds: 15), // Increased timeout
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
    } on TimeoutException catch (_) {
      return 'Connection timed out. Please check your network and try again.';
    } catch (e) {
      return 'Network error: ${e.toString()}';
    }
  }

  Future<void> logout() async {
    try {
      _isAuthenticated = false;
      _isAdmin = false;
      _email = null;

      // Clear stored user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      notifyListeners();
    } catch (e) {
      debugPrint('Error during logout: $e');
      // Still notify listeners even if preferences clear fails
      notifyListeners();
    }
  }

  // Initialize auth state from stored preferences
  Future<void> initializeAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
      _isAdmin = prefs.getBool('isAdmin') ?? false;
      _email = prefs.getString('email');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing auth state: $e');
      // Set to default unauthenticated state on error
      _isAuthenticated = false;
      _isAdmin = false;
      _email = null;
      notifyListeners();
    }
  }
}