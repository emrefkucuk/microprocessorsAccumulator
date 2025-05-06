import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/air_quality_data.dart';
import '../models/sensor_data.dart';
import 'data_service.dart';

/// A simplified notification service that stores settings and logs notifications
/// but doesn't actually show them.
/// This can be replaced with a full implementation later.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Notification settings
  bool _healthAdviceEnabled = true;
  bool _extremeValueAlertsEnabled = true;
  bool _dailyReportsEnabled = true;

  // Timers
  Timer? _healthAdviceTimer;
  Timer? _dailyReportTimer;

  // Initialize the notifications service
  Future<void> init() async {
    // Load settings from persistent storage
    await _loadSettings();

    debugPrint('🔔 Notification service initialized (simulated mode)');

    // Set up data stream listeners
    DataService().airQualityStream.listen(_checkAirQualityAlerts);
    DataService().sensorsStream.listen(_checkSensorAlerts);

    // Set up periodic notifications
    _setupPeriodicNotifications();
  }

  // Load notification settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _healthAdviceEnabled = prefs.getBool('healthAdviceEnabled') ?? true;
      _extremeValueAlertsEnabled =
          prefs.getBool('extremeValueAlertsEnabled') ?? true;
      _dailyReportsEnabled = prefs.getBool('dailyReportsEnabled') ?? true;
    } catch (e) {
      debugPrint('Failed to load notification settings: $e');
      // Fall back to defaults
      _healthAdviceEnabled = true;
      _extremeValueAlertsEnabled = true;
      _dailyReportsEnabled = true;
    }
  }

  // Save notification settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('healthAdviceEnabled', _healthAdviceEnabled);
      await prefs.setBool(
          'extremeValueAlertsEnabled', _extremeValueAlertsEnabled);
      await prefs.setBool('dailyReportsEnabled', _dailyReportsEnabled);
    } catch (e) {
      debugPrint('Failed to save notification settings: $e');
    }
  }

  // Getters for notification settings
  bool get healthAdviceEnabled => _healthAdviceEnabled;
  bool get extremeValueAlertsEnabled => _extremeValueAlertsEnabled;
  bool get dailyReportsEnabled => _dailyReportsEnabled;

  // Update notification settings
  Future<void> updateSettings({
    bool? healthAdviceEnabled,
    bool? extremeValueAlertsEnabled,
    bool? dailyReportsEnabled,
  }) async {
    bool settingsChanged = false;

    if (healthAdviceEnabled != null &&
        healthAdviceEnabled != _healthAdviceEnabled) {
      _healthAdviceEnabled = healthAdviceEnabled;
      settingsChanged = true;
    }

    if (extremeValueAlertsEnabled != null &&
        extremeValueAlertsEnabled != _extremeValueAlertsEnabled) {
      _extremeValueAlertsEnabled = extremeValueAlertsEnabled;
      settingsChanged = true;
    }

    if (dailyReportsEnabled != null &&
        dailyReportsEnabled != _dailyReportsEnabled) {
      _dailyReportsEnabled = dailyReportsEnabled;
      settingsChanged = true;
    }

    if (settingsChanged) {
      await _saveSettings();
      _setupPeriodicNotifications();
    }
  }

  // Set up periodic notifications based on current settings
  void _setupPeriodicNotifications() {
    // Cancel existing timers
    _healthAdviceTimer?.cancel();
    _dailyReportTimer?.cancel();

    // Set up health advice timer (every 6 hours) if enabled
    if (_healthAdviceEnabled) {
      _healthAdviceTimer =
          Timer.periodic(const Duration(hours: 6), (_) => _sendHealthAdvice());
    }

    // Set up daily report timer (at 5 PM) if enabled
    if (_dailyReportsEnabled) {
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
    if (!_extremeValueAlertsEnabled) return;

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
    if (!_extremeValueAlertsEnabled) return;

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
    if (!_dailyReportsEnabled) return;

    final data = DataService().currentAirQuality;

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
    if (!_healthAdviceEnabled) return;

    final data = DataService().currentAirQuality;
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
  }
}
