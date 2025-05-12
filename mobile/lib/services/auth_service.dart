import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Backend URL - automatically detect if running on emulator
  String get baseUrl {
    // If running on Android emulator, use special IP for localhost
    // Otherwise, use localhost directly
    if (Platform.isAndroid) {
      // Check if the host name contains 'emulator' or if we're in debug mode
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://localhost:8000';
    }
  }

  // Keys for storing data
  static const String _authKey = 'is_authenticated';
  static const String _userEmailKey = 'user_email';
  static const String _authTokenKey = 'auth_token';

  // Check if user is logged in
  Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasToken = prefs.getString(_authTokenKey) != null;
      final isAuth = prefs.getBool(_authKey) ?? false;
      return hasToken && isAuth;
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      return false;
    }
  }

  // Get current auth token
  Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_authTokenKey);
    } catch (e) {
      debugPrint('Error getting auth token: $e');
      return null;
    }
  }

  // Get current user email
  Future<String?> getCurrentUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Login with email and password
  Future<bool> login(String email, String password) async {
    try {
      debugPrint('Attempting to login to: ${baseUrl}/auth/login');

      final response = await http.post(
        Uri.parse('${baseUrl}/auth/login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username':
              email, // Backend expects 'username' but it's actually email
          'password': password,
        },
      );

      debugPrint('Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        final tokenType = data['token_type'];

        // Save authentication data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_authKey, true);
        await prefs.setString(_userEmailKey, email);
        await prefs.setString(_authTokenKey, '$tokenType $token');

        return true;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Login failed: ${errorData['detail']}');
        return false;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Register a new user
  Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      debugPrint('Attempting to register to: ${baseUrl}/auth/register');

      final response = await http.post(
        Uri.parse('${baseUrl}/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      debugPrint('Register response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Registration successful',
          'data': data,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['detail'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      return {
        'success': false,
        'message': 'Network error occurred: $e',
      };
    }
  }

  // Get current user info from backend
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final token = await getAuthToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${baseUrl}/auth/me'),
        headers: {
          'Authorization': token,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to get user info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return null;
    }
  }

  // Logout the current user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authKey, false);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_authTokenKey);
      await prefs.setBool('remember_me', false); // Remember Me sıfırlansın
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }
}
