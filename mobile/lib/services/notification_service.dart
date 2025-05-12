import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/air_quality_data.dart';
import '../models/sensor_data.dart';
import 'auth_service.dart';
import 'user_settings_service.dart';
import 'data_service.dart';

/// Enhanced notification service that integrates with backend alerts
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Backend URL - automatically detect if running on emulator
  String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else {
      return 'http://localhost:8000/api';
    }
  }

  // Timers
  Timer? _healthAdviceTimer;
  Timer? _dailyReportTimer;
  Timer? _alertCheckTimer;

  // Settings service reference
  final UserSettingsService _settingsService = UserSettingsService();

  // Notification settings (synced with backend)
  bool get healthAdviceEnabled =>
      _settingsService.getSetting<bool>('health_advice_enabled') ?? true;
  bool get extremeValueAlertsEnabled =>
      _settingsService.getSetting<bool>('extreme_value_alerts_enabled') ?? true;
  bool get dailyReportsEnabled =>
      _settingsService.getSetting<bool>('daily_reports_enabled') ?? true;

  // Initialize the notifications service
  // Initialize the notifications service
  Future<void> init() async {
    debugPrint('🔔 Notification service initialized');

    // Set up data stream listeners with error handling
    DataService().airQualityStream.listen(
      _checkAirQualityAlerts,
      onError: (error) {
        debugPrint('Error in air quality stream: $error');
      },
    );

    DataService().sensorsStream.listen(
      _checkSensorAlerts,
      onError: (error) {
        debugPrint('Error in sensors stream: $error');
      },
    );

    // Set up periodic notifications
    _setupPeriodicNotifications();

    // Start checking for backend alerts every time data is fetched
    _startAlertChecking();
  }

  // Start checking backend alerts regularly
  void _startAlertChecking() {
    _alertCheckTimer?.cancel();
    _alertCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkBackendAlerts(),
    );
  }

  // Check for new alerts from backend
  Future<void> _checkBackendAlerts() async {
    try {
      final headers = await _getHeaders();
      if (headers['Authorization'] == null) return; // Not logged in

      final response = await http.get(
        Uri.parse('$baseUrl/alerts/recent'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> alerts = json.decode(response.body);

        for (final alert in alerts) {
          if (!alert['acknowledged']) {
            _showBackendAlert(alert);
            // Mark as acknowledged in backend
            await _acknowledgeAlert(alert['id']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking backend alerts: $e');
    }
  }

  // Show a backend alert
  void _showBackendAlert(Map<String, dynamic> alert) {
    final type = alert['type']?.toString().toUpperCase() ?? 'UNKNOWN';
    final value = alert['value'];
    final threshold = alert['threshold'];
    final alertId = (alert['id'] as num).toInt(); // Convert num to int

    _showNotification(
      id: 100 + alertId, // Now uses int instead of num
      title: '$type Alert!',
      body: '$type value ($value) exceeded threshold ($threshold)',
      priority: 'high',
    );
  }

  // Acknowledge an alert in the backend
  Future<void> _acknowledgeAlert(int alertId) async {
    try {
      final headers = await _getHeaders();

      // Note: This endpoint might need to be implemented in your backend
      await http.put(
        Uri.parse('$baseUrl/alerts/$alertId/acknowledge'),
        headers: headers,
      );
    } catch (e) {
      debugPrint('Error acknowledging alert: $e');
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

  // Update notification settings
  Future<void> updateSettings({
    bool? healthAdviceEnabled,
    bool? extremeValueAlertsEnabled,
    bool? dailyReportsEnabled,
  }) async {
    final updates = <String, dynamic>{};

    if (healthAdviceEnabled != null) {
      updates['health_advice_enabled'] = healthAdviceEnabled;
    }
    if (extremeValueAlertsEnabled != null) {
      updates['extreme_value_alerts_enabled'] = extremeValueAlertsEnabled;
    }
    if (dailyReportsEnabled != null) {
      updates['daily_reports_enabled'] = dailyReportsEnabled;
    }

    if (updates.isNotEmpty) {
      await _settingsService.updateSettings(updates);
      _setupPeriodicNotifications();
    }
  }

  // Set up periodic notifications based on current settings
  void _setupPeriodicNotifications() {
    // Cancel existing timers
    _healthAdviceTimer?.cancel();
    _dailyReportTimer?.cancel();

    // Set up health advice timer (every 6 hours) if enabled
    if (healthAdviceEnabled) {
      _healthAdviceTimer =
          Timer.periodic(const Duration(hours: 6), (_) => _sendHealthAdvice());
    }

    // Set up daily report timer (at 5 PM) if enabled
    if (dailyReportsEnabled) {
      _scheduleDailyReportAt5PM();
    }
  }

  // Schedule daily report at 5 PM
  void _scheduleDailyReportAt5PM() {
    // Cancel any existing timer
    _dailyReportTimer?.cancel();

    // Calculate time until next 5 PM
    final now = DateTime.now();
    final fivePM = DateTime(now.year, now.month, now.day, 17, 0);
    final timeUntil5PM = now.hour < 17
        ? fivePM.difference(now)
        : fivePM.add(const Duration(days: 1)).difference(now);

    // Schedule the first report
    _dailyReportTimer = Timer(timeUntil5PM, () {
      _sendDailyReport();

      // Then set up a daily timer
      _dailyReportTimer =
          Timer.periodic(const Duration(days: 1), (_) => _sendDailyReport());
    });
  }

  // Check air quality data for potential alerts
  void _checkAirQualityAlerts(AirQualityData data) {
    if (!extremeValueAlertsEnabled) return;

    // Send alert if status is unhealthy
    if (data.status == AirQualityStatus.unhealthy) {
      _showNotification(
        id: 1,
        title: 'Air Quality Alert',
        body:
            'Air quality has deteriorated to unhealthy levels (AQI: ${data.aqi}).',
        priority: 'high',
      );
    }
  }

  // Check sensor data for extreme values
  void _checkSensorAlerts(List<SensorData> sensors) {
    if (!extremeValueAlertsEnabled) return;

    for (final sensor in sensors) {
      if (sensor.status == SensorStatus.critical) {
        _showNotification(
          id: 2,
          title: '${sensor.name} Alert',
          body:
              '${sensor.name} has reached critical levels: ${sensor.value} ${sensor.unit}',
          priority: 'critical',
        );
      } else if (sensor.status == SensorStatus.warning) {
        _showNotification(
          id: 3,
          title: '${sensor.name} Warning',
          body:
              '${sensor.name} has reached warning levels: ${sensor.value} ${sensor.unit}',
          priority: 'high',
        );
      }
    }
  }

  // Send daily air quality report
  void _sendDailyReport() {
    if (!dailyReportsEnabled) return;

    final data = DataService().currentAirQuality;
    if (data == null) return;

    String statusText;
    switch (data.status) {
      case AirQualityStatus.good:
        statusText = 'Good';
        break;
      case AirQualityStatus.moderate:
        statusText = 'Moderate';
        break;
      case AirQualityStatus.unhealthy:
        statusText = 'Unhealthy';
        break;
    }

    _showNotification(
      id: 4,
      title: 'Daily Air Quality Report',
      body:
          'Today\'s average AQI: ${data.aqi} ($statusText). Temperature: ${data.temperature}°C, Humidity: ${data.humidity}%',
      priority: 'normal',
    );
  }

  // Send periodic health advice
  void _sendHealthAdvice() {
    if (!healthAdviceEnabled) return;

    final data = DataService().currentAirQuality;
    if (data == null) return;

    String advice;

    if (data.status == AirQualityStatus.good) {
      advice = 'Air quality is good. Perfect time for outdoor activities!';
    } else if (data.status == AirQualityStatus.moderate) {
      advice =
          'Air quality is moderate. Consider reducing prolonged outdoor activities if you\'re sensitive.';
    } else {
      advice =
          'Air quality is unhealthy. Consider staying indoors and keeping windows closed.';
    }

    _showNotification(
      id: 5,
      title: 'Health Advice',
      body: advice,
      priority: 'low',
    );
  }

  // Log a notification instead of showing it
  void _showNotification({
    required int id,
    required String title,
    required String body,
    required String priority,
  }) {
    // Just log the notification for now
    debugPrint('🔔 NOTIFICATION ($priority): $title - $body');

    // In a real app, you would show a proper system notification here
    // This can be implemented later when the notification issue is fixed
  }

  // Clean up resources
  void dispose() {
    _healthAdviceTimer?.cancel();
    _dailyReportTimer?.cancel();
    _alertCheckTimer?.cancel();
  }
}
