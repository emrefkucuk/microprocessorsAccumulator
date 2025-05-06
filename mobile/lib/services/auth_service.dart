import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Mock user credentials for development
  static const String _mockEmail = 'admin@gmail.com';
  static const String _mockPassword = 'admin';

  // Key for storing authentication status
  static const String _authKey = 'is_authenticated';
  static const String _userEmailKey = 'user_email';

  // Check if user is logged in
  Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_authKey) ?? false;
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      return false;
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
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // For mock authentication, check against hardcoded credentials
      final success = email == _mockEmail && password == _mockPassword;

      if (success) {
        // Save authentication status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_authKey, true);
        await prefs.setString(_userEmailKey, email);
      }

      return success;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Register a new user (mock implementation)
  Future<bool> register(String email, String password) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // This is a placeholder for future API integration
      // Always returns false for now as registration is disabled
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  // Logout the current user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authKey, false);
      await prefs.remove(_userEmailKey);
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }
}
