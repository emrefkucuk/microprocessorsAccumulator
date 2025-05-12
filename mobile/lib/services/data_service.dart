import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/air_quality_data.dart';
import '../models/sensor_data.dart';
import 'auth_service.dart';
import 'dart:io';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // Backend URL
  // Backend URL - automatically detect if running on emulator
  String get baseUrl {
    // If running on Android emulator, use special IP for localhost
    // Otherwise, use localhost directly
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else {
      return 'http://localhost:8000/api';
    }
  }

  // Stream controllers to broadcast data updates
  final _airQualityStreamController =
      StreamController<AirQualityData>.broadcast();
  final _sensorsStreamController =
      StreamController<List<SensorData>>.broadcast();

  // Current data storage
  AirQualityData? _currentAirQuality;
  List<SensorData> _sensorReadings = [];
  List<AirQualityData> _dailyAirQuality = [];
  List<AirQualityData> _monthlyAirQuality = [];

  // Streams that components can listen to
  Stream<AirQualityData> get airQualityStream =>
      _airQualityStreamController.stream;
  Stream<List<SensorData>> get sensorsStream => _sensorsStreamController.stream;

  // Access to current data
  AirQualityData? get currentAirQuality => _currentAirQuality;
  List<SensorData> get sensorReadings => _sensorReadings;
  List<AirQualityData> get dailyAirQuality => _dailyAirQuality;
  List<AirQualityData> get monthlyAirQuality => _monthlyAirQuality;

  // Update timer
  Timer? _updateTimer;

  // Refresh rate in seconds (configurable in settings)
  int _refreshRate = 30;

  // Initialize the service
  Future<void> init() async {
    await _loadRefreshRate();
    await _loadCachedData();

    // Do an initial update
    await _updateData();

    // Start periodic updates
    _startPeriodicUpdates();
  }

  // Load refresh rate from settings
  Future<void> _loadRefreshRate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _refreshRate = prefs.getInt('refresh_rate') ?? 30;
    } catch (e) {
      debugPrint('Error loading refresh rate: $e');
      _refreshRate = 30;
    }
  }

  // Update refresh rate
  Future<void> updateRefreshRate(int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('refresh_rate', seconds);
      _refreshRate = seconds;

      // Restart periodic updates with new rate
      _startPeriodicUpdates();
    } catch (e) {
      debugPrint('Error updating refresh rate: $e');
    }
  }

  // Start periodic updates
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      Duration(seconds: _refreshRate),
      (_) => _updateData(),
    );
  }

  // Load cached data for offline mode
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load current air quality
      final currentJson = prefs.getString('current_air_quality');
      if (currentJson != null) {
        _currentAirQuality = AirQualityData.fromJson(json.decode(currentJson));
      }

      // Load sensor readings
      final sensorsJson = prefs.getString('sensor_readings');
      if (sensorsJson != null) {
        final List<dynamic> jsonList = json.decode(sensorsJson);
        _sensorReadings =
            jsonList.map((item) => SensorData.fromJson(item)).toList();
      }

      // Load daily data
      final dailyJson = prefs.getString('daily_air_quality');
      if (dailyJson != null) {
        final List<dynamic> jsonList = json.decode(dailyJson);
        _dailyAirQuality =
            jsonList.map((item) => AirQualityData.fromJson(item)).toList();
      }

      // Load monthly data
      final monthlyJson = prefs.getString('monthly_air_quality');
      if (monthlyJson != null) {
        final List<dynamic> jsonList = json.decode(monthlyJson);
        _monthlyAirQuality =
            jsonList.map((item) => AirQualityData.fromJson(item)).toList();
      }

      // Notify listeners with cached data
      if (_currentAirQuality != null) {
        _airQualityStreamController.add(_currentAirQuality!);
      }
      _sensorsStreamController.add(_sensorReadings);
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  // Save data to cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_currentAirQuality != null) {
        await prefs.setString(
          'current_air_quality',
          json.encode(_currentAirQuality!.toJson()),
        );
      }

      await prefs.setString(
        'sensor_readings',
        json.encode(_sensorReadings.map((s) => s.toJson()).toList()),
      );

      await prefs.setString(
        'daily_air_quality',
        json.encode(_dailyAirQuality.map((a) => a.toJson()).toList()),
      );

      await prefs.setString(
        'monthly_air_quality',
        json.encode(_monthlyAirQuality.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving to cache: $e');
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

  // Fetch current data from API
  // Fetch current data from API
  Future<void> _updateData({int retryCount = 0}) async {
    try {
      final headers = await _getHeaders();

      debugPrint('Fetching data from: ${baseUrl}/sensors/current');
      debugPrint('Headers: $headers');

      // Fetch current sensor data
      final currentResponse = await http.get(
        Uri.parse('${baseUrl}/sensors/current'),
        headers: headers,
      );

      debugPrint('Current data response status: ${currentResponse.statusCode}');
      debugPrint('Current data response body: ${currentResponse.body}');

      if (currentResponse.statusCode == 200) {
        final data = json.decode(currentResponse.body);

        // Convert backend sensor data to our format
        _currentAirQuality = _convertToAirQualityData(data);
        _sensorReadings = _convertToSensorDataList(data);

        // Fetch historical data less frequently (every 10 minutes)
        if (DateTime.now().minute % 10 == 0) {
          await _fetchHistoricalData();
        }

        // Save to cache
        await _saveToCache();

        // Notify listeners
        _airQualityStreamController.add(_currentAirQuality!);
        _sensorsStreamController.add(_sensorReadings);
      } else {
        debugPrint('Error response status: ${currentResponse.statusCode}');
        debugPrint('Error response body: ${currentResponse.body}');
        throw Exception('Failed to fetch data: ${currentResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to update data: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      // Retry logic
      if (retryCount < 3) {
        await Future.delayed(Duration(seconds: 5 << retryCount));
        return _updateData(retryCount: retryCount + 1);
      }

      // Fall back to cached data if available
      if (_currentAirQuality != null) {
        debugPrint('Using cached data due to network error');
        _airQualityStreamController.add(_currentAirQuality!);
        _sensorsStreamController.add(_sensorReadings);
      }
    }
  }

  // Fetch historical data
  Future<void> _fetchHistoricalData() async {
    try {
      final headers = await _getHeaders();
      final now = DateTime.now();

      // Fetch daily data (24 hours)
      final dailyStart = now.subtract(const Duration(hours: 24));
      final dailyResponse = await http.get(
        Uri.parse(
            '$baseUrl/sensors/history?start=${dailyStart.toIso8601String()}&end=${now.toIso8601String()}'),
        headers: headers,
      );

      if (dailyResponse.statusCode == 200) {
        final List<dynamic> dailyData = json.decode(dailyResponse.body);
        _dailyAirQuality =
            dailyData.map((item) => _convertToAirQualityData(item)).toList();
      }

      // Fetch monthly data (30 days)
      final monthlyStart = now.subtract(const Duration(days: 30));
      final monthlyResponse = await http.get(
        Uri.parse(
            '$baseUrl/sensors/history?start=${monthlyStart.toIso8601String()}&end=${now.toIso8601String()}'),
        headers: headers,
      );

      if (monthlyResponse.statusCode == 200) {
        final List<dynamic> monthlyData = json.decode(monthlyResponse.body);
        _monthlyAirQuality =
            monthlyData.map((item) => _convertToAirQualityData(item)).toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch historical data: $e');
    }
  }

  // Convert backend data to AirQualityData
  AirQualityData _convertToAirQualityData(Map<String, dynamic> data) {
    // Calculate AQI based on sensor values
    final pm25 = data['pm25'] ?? 0.0;
    final pm10 = data['pm10'] ?? 0.0;
    final co2 = data['co2'] ?? 0.0;

    int aqi = _calculateAQI(pm25, pm10, co2);

    AirQualityStatus status;
    if (aqi < 50) {
      status = AirQualityStatus.good;
    } else if (aqi < 100) {
      status = AirQualityStatus.moderate;
    } else {
      status = AirQualityStatus.unhealthy;
    }

    return AirQualityData(
      aqi: aqi,
      temperature: data['temperature'] ?? 0.0,
      humidity: data['humidity'] ?? 0.0,
      status: status,
      timestamp: DateTime.parse(data['timestamp']),
    );
  }

  // Convert backend data to SensorData list
  List<SensorData> _convertToSensorDataList(Map<String, dynamic> data) {
    final timestamp = DateTime.parse(data['timestamp']);

    return [
      SensorData(
        name: 'Temperature',
        value: data['temperature'] ?? 0.0,
        unit: '°C',
        status: _getSensorStatus('temperature', data['temperature'] ?? 0.0),
        timestamp: timestamp,
      ),
      SensorData(
        name: 'Humidity',
        value: data['humidity'] ?? 0.0,
        unit: '%',
        status: _getSensorStatus('humidity', data['humidity'] ?? 0.0),
        timestamp: timestamp,
      ),
      SensorData(
        name: 'PM2.5',
        value: data['pm25'] ?? 0.0,
        unit: 'μg/m³',
        status: _getSensorStatus('pm25', data['pm25'] ?? 0.0),
        timestamp: timestamp,
      ),
      SensorData(
        name: 'PM10',
        value: data['pm10'] ?? 0.0,
        unit: 'μg/m³',
        status: _getSensorStatus('pm10', data['pm10'] ?? 0.0),
        timestamp: timestamp,
      ),
      SensorData(
        name: 'CO2',
        value: data['co2'] ?? 0.0,
        unit: 'ppm',
        status: _getSensorStatus('co2', data['co2'] ?? 0.0),
        timestamp: timestamp,
      ),
      SensorData(
        name: 'VOC',
        value: data['voc'] ?? 0.0,
        unit: 'mg/m³',
        status: _getSensorStatus('voc', data['voc'] ?? 0.0),
        timestamp: timestamp,
      ),
    ];
  }

  // Calculate AQI from sensor values
  int _calculateAQI(double pm25, double pm10, double co2) {
    // This is a simplified AQI calculation - you can make it more accurate
    double aqiFromPM25 = (pm25 / 35) * 100;
    double aqiFromPM10 = (pm10 / 50) * 100;
    double aqiFromCO2 = (co2 / 1000) * 50;

    return (aqiFromPM25 + aqiFromPM10 + aqiFromCO2).round().clamp(0, 500);
  }

  // Get sensor status based on value
  SensorStatus _getSensorStatus(String sensorType, double value) {
    switch (sensorType) {
      case 'temperature':
        if (value > 35 || value < 0) return SensorStatus.critical;
        if (value > 30 || value < 5) return SensorStatus.warning;
        return SensorStatus.normal;
      case 'humidity':
        if (value > 80 || value < 20) return SensorStatus.critical;
        if (value > 70 || value < 30) return SensorStatus.warning;
        return SensorStatus.normal;
      case 'pm25':
        if (value > 55) return SensorStatus.critical;
        if (value > 35) return SensorStatus.warning;
        return SensorStatus.normal;
      case 'pm10':
        if (value > 100) return SensorStatus.critical;
        if (value > 50) return SensorStatus.warning;
        return SensorStatus.normal;
      case 'co2':
        if (value > 1500) return SensorStatus.critical;
        if (value > 1000) return SensorStatus.warning;
        return SensorStatus.normal;
      case 'voc':
        if (value > 1.0) return SensorStatus.critical;
        if (value > 0.5) return SensorStatus.warning;
        return SensorStatus.normal;
      default:
        return SensorStatus.normal;
    }
  }

  // Force an immediate data update
  Future<void> refreshData() async {
    return _updateData();
  }

  // Clean up resources
  void dispose() {
    _updateTimer?.cancel();
    _airQualityStreamController.close();
    _sensorsStreamController.close();
  }
}
