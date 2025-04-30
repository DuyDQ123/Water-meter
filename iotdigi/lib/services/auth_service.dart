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

  // Update server IP to match your network configuration
  static const String baseUrl = 'http://192.168.1.159/iotdigi-main';

  Future<String?> login(String email, String password) async {
    try {
      debugPrint('Attempting login to: $baseUrl/auth_login.php');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth_login.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 10),
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('Server error with status code: ${response.statusCode}');
        return 'Server error: ${response.statusCode}';
      }

      Map<String, dynamic>? data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint('JSON decode error: $e');
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
          debugPrint('Error saving user data: $e');
          return 'Error saving user data: $e';
        }
      }

      return data['error'] ?? 'Login failed';
    } on TimeoutException catch (_) {
      debugPrint('Connection timed out');
      return 'Connection timed out. Please check your network and try again.';
    } catch (e) {
      debugPrint('Network error: $e');
      return 'Network error: ${e.toString()}';
    }
  }

  Future<String?> register(String email, String password) async {
    try {
      debugPrint('Attempting registration to: $baseUrl/auth_register.php');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth_register.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 10),
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

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
      debugPrint('Connection timed out');
      return 'Connection timed out. Please check your network and try again.';
    } catch (e) {
      debugPrint('Network error: $e');
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