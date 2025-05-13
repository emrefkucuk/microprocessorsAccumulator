import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class UserSettingsService {
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;
  UserSettingsService._internal();

  // Backend URL - automatically detect if running on emulator
  String get baseUrl {
    // If running on Android emulator, use special IP for localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else {
      return 'http://localhost:8000/api';
    }
  }

  // Stream controller for settings updates
  final _settingsStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Current settings
  Map<String, dynamic> _currentSettings = {
    'notifications': true,
    'format': 'metric',
    'thresholds': {
      'co2': 1000,
      'pm25': 35,
      'pm10': 50,
      'voc': 500,
    },
    'refresh_rate': 30,
    'health_advice_enabled': true,
    'extreme_value_alerts_enabled': true,
    'daily_reports_enabled': true,
  };

  // Stream that components can listen to
  Stream<Map<String, dynamic>> get settingsStream =>
      _settingsStreamController.stream;

  // Access to current settings
  Map<String, dynamic> get currentSettings => Map.from(_currentSettings);

  // Initialize the service
  Future<void> init() async {
    await _loadSettingsFromLocal();
    await _syncWithBackend();
  }

  // Load settings from local storage
  Future<void> _loadSettingsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('user_settings');

      if (settingsJson != null) {
        _currentSettings = json.decode(settingsJson);
        _settingsStreamController.add(_currentSettings);
      }
    } catch (e) {
      debugPrint('Error loading local settings: $e');
    }
  }

  // Save settings to local storage
  Future<void> _saveSettingsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_settings', json.encode(_currentSettings));
    } catch (e) {
      debugPrint('Error saving local settings: $e');
    }
  }

  // Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // Sync with backend
  Future<void> _syncWithBackend() async {
    try {
      final headers = await _getHeaders();

      debugPrint('Syncing settings from: $baseUrl/settings');

      // Fetch settings from backend
      final response = await http.get(
        Uri.parse('$baseUrl/settings'),
        headers: headers,
      );

      debugPrint('Settings sync response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final backendSettings = json.decode(response.body);

        // Merge with existing settings (keep local refresh_rate and notification settings)
        final refreshRate = _currentSettings['refresh_rate'];
        final healthAdviceEnabled = _currentSettings['health_advice_enabled'];
        final extremeValueAlertsEnabled =
            _currentSettings['extreme_value_alerts_enabled'];
        final dailyReportsEnabled = _currentSettings['daily_reports_enabled'];

        _currentSettings = {
          'notifications': backendSettings['notifications'] ?? true,
          'format': backendSettings['format'] ?? 'metric',
          'thresholds': backendSettings['thresholds'] ??
              {
                'co2': 1000,
                'pm25': 35,
                'pm10': 50,
                'voc': 500,
              },
          'refresh_rate': refreshRate ?? 30,
          'health_advice_enabled': healthAdviceEnabled ?? true,
          'extreme_value_alerts_enabled': extremeValueAlertsEnabled ?? true,
          'daily_reports_enabled': dailyReportsEnabled ?? true,
        };

        await _saveSettingsToLocal();
        _settingsStreamController.add(_currentSettings);
      }
    } catch (e) {
      debugPrint('Error syncing with backend: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  // Update settings
  Future<bool> updateSettings(Map<String, dynamic> updates) async {
    try {
      // Update local settings first
      _currentSettings = {..._currentSettings, ...updates};
      await _saveSettingsToLocal();
      _settingsStreamController.add(_currentSettings);

      // Prepare backend update (exclude refresh_rate and notification settings which are local only)
      final backendUpdates = Map<String, dynamic>.from(updates);
      backendUpdates.remove('refresh_rate');
      backendUpdates.remove('health_advice_enabled');
      backendUpdates.remove('extreme_value_alerts_enabled');
      backendUpdates.remove('daily_reports_enabled');

      if (backendUpdates.isNotEmpty) {
        final headers = await _getHeaders();

        debugPrint('Updating backend settings: $backendUpdates');

        final response = await http.post(
          Uri.parse('$baseUrl/settings'),
          headers: headers,
          body: json.encode({
            'notifications': _currentSettings['notifications'],
            'format': _currentSettings['format'],
            'thresholds': _currentSettings['thresholds'],
          }),
        );

        debugPrint('Settings update response status: ${response.statusCode}');

        if (response.statusCode != 200) {
          throw Exception(
              'Failed to update settings on server: ${response.statusCode}');
        }
      }

      // If refresh rate was updated, notify DataService
      if (updates.containsKey('refresh_rate')) {
        // This would need to be passed to DataService
        // For now, we'll store it in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('refresh_rate', updates['refresh_rate']);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating settings: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      // Revert local changes on error
      await _loadSettingsFromLocal();
      return false;
    }
  }

  // Get specific setting value
  T? getSetting<T>(String key) {
    final value = _currentSettings[key];
    if (value is T) {
      return value;
    }
    return null;
  }

  // Get nested setting value (e.g., 'thresholds.co2')
  T? getNestedSetting<T>(String path) {
    final parts = path.split('.');
    dynamic current = _currentSettings;

    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    if (current is T) {
      return current;
    }
    return null;
  }

  // Update nested setting value
  Future<bool> updateNestedSetting(String path, dynamic value) async {
    final parts = path.split('.');
    if (parts.isEmpty) return false;

    // Create a copy to modify
    final newSettings = Map<String, dynamic>.from(_currentSettings);
    dynamic current = newSettings;

    for (int i = 0; i < parts.length - 1; i++) {
      if (current is Map) {
        if (!current.containsKey(parts[i])) {
          current[parts[i]] = <String, dynamic>{};
        }
        current = current[parts[i]];
      } else {
        return false;
      }
    }

    if (current is Map) {
      current[parts.last] = value;
      return await updateSettings(newSettings);
    }

    return false;
  }

  // Dispose of resources
  void dispose() {
    _settingsStreamController.close();
  }
}
