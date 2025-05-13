import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/air_quality_data.dart';
import '../models/sensor_data.dart';
import 'auth_service.dart';

// Global navigator key to show SnackBar messages
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // Backend URL - automatically detect if running on emulator
  String get baseUrl {
    // If running on Android emulator, use special IP for localhost
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
  final _dailyAirQualityStreamController =
      StreamController<List<AirQualityData>>.broadcast();
  final _monthlyAirQualityStreamController =
      StreamController<List<AirQualityData>>.broadcast();

  // Current data storage
  AirQualityData? _currentAirQuality;
  List<SensorData> _sensorReadings = [];
  List<AirQualityData> _dailyAirQuality = [];
  List<AirQualityData> _monthlyAirQuality = [];

  // Streams that components can listen to
  Stream<AirQualityData> get airQualityStream =>
      _airQualityStreamController.stream;
  Stream<List<SensorData>> get sensorsStream => _sensorsStreamController.stream;
  Stream<List<AirQualityData>> get dailyAirQualityStream =>
      _dailyAirQualityStreamController.stream;
  Stream<List<AirQualityData>> get monthlyAirQualityStream =>
      _monthlyAirQualityStreamController.stream;

  // Access to current data
  AirQualityData? get currentAirQuality => _currentAirQuality;
  List<SensorData> get sensorReadings => _sensorReadings;
  List<AirQualityData> get dailyAirQuality => _dailyAirQuality;
  List<AirQualityData> get monthlyAirQuality => _monthlyAirQuality;

  // Update timer
  Timer? _updateTimer;

  // Refresh rate in seconds (configurable in settings)
  int _refreshRate = 30;

  // Track whether we have a pending historical data fetch
  bool _fetchingHistoricalData = false;

  // Initialize the service
  Future<void> init() async {
    debugPrint('Initializing DataService');
    await _loadRefreshRate();
    await _loadCachedData();

    // Do an initial update - this will trigger historical data fetching too
    await _updateData().catchError((e) {
      debugPrint('Error during initial data update: $e');
    });

    // Start periodic updates
    _startPeriodicUpdates();

    debugPrint('DataService initialization complete');
  }

  // Load refresh rate from settings
  Future<void> _loadRefreshRate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _refreshRate = prefs.getInt('refresh_rate') ?? 30;
      debugPrint('Loaded refresh rate: $_refreshRate seconds');
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
      debugPrint('Updated refresh rate to: $_refreshRate seconds');

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
    debugPrint('Started periodic updates every $_refreshRate seconds');
  }

  // Load cached data for offline mode
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load current air quality
      final currentJson = prefs.getString('current_air_quality');
      if (currentJson != null) {
        _currentAirQuality = AirQualityData.fromJson(json.decode(currentJson));
        debugPrint('Loaded cached current air quality data');
      }

      // Load sensor readings
      final sensorsJson = prefs.getString('sensor_readings');
      if (sensorsJson != null) {
        final List<dynamic> jsonList = json.decode(sensorsJson);
        _sensorReadings =
            jsonList.map((item) => SensorData.fromJson(item)).toList();
        debugPrint('Loaded ${_sensorReadings.length} cached sensor readings');
      }

      // Load daily data
      final dailyJson = prefs.getString('daily_air_quality');
      if (dailyJson != null) {
        final List<dynamic> jsonList = json.decode(dailyJson);
        _dailyAirQuality =
            jsonList.map((item) => AirQualityData.fromJson(item)).toList();
        debugPrint('Loaded ${_dailyAirQuality.length} cached daily readings');

        // Make sure to push to stream
        if (_dailyAirQuality.isNotEmpty) {
          _dailyAirQualityStreamController.add(_dailyAirQuality);
        }
      }

      // Load monthly data
      final monthlyJson = prefs.getString('monthly_air_quality');
      if (monthlyJson != null) {
        final List<dynamic> jsonList = json.decode(monthlyJson);
        _monthlyAirQuality =
            jsonList.map((item) => AirQualityData.fromJson(item)).toList();
        debugPrint(
            'Loaded ${_monthlyAirQuality.length} cached monthly readings');

        // Make sure to push to stream
        if (_monthlyAirQuality.isNotEmpty) {
          _monthlyAirQualityStreamController.add(_monthlyAirQuality);
        }
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

      if (_dailyAirQuality.isNotEmpty) {
        await prefs.setString(
          'daily_air_quality',
          json.encode(_dailyAirQuality.map((a) => a.toJson()).toList()),
        );
      }

      if (_monthlyAirQuality.isNotEmpty) {
        await prefs.setString(
          'monthly_air_quality',
          json.encode(_monthlyAirQuality.map((a) => a.toJson()).toList()),
        );
      }

      debugPrint('Saved all data to cache');
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

  // Fetch current data and AI prediction from API
  Future<void> _updateData({int retryCount = 0}) async {
    try {
      final headers = await _getHeaders();

      // Debug info
      debugPrint('Fetching current sensor data from: $baseUrl/sensors/current');

      // Fetch current sensor data
      final currentResponse = await http.get(
        Uri.parse('$baseUrl/sensors/current'),
        headers: headers,
      );

      debugPrint('Current data response status: ${currentResponse.statusCode}');

      if (currentResponse.statusCode == 200) {
        try {
          final data = json.decode(currentResponse.body);
          debugPrint('Current data retrieved successfully');

          // Convert backend sensor data to our format
          _currentAirQuality = _convertToAirQualityData(data);
          _sensorReadings = _convertToSensorDataList(data);

          // Fetch AI prediction
          await _fetchAIPrediction();

          // Always fetch historical data if empty
          if (_dailyAirQuality.isEmpty || _monthlyAirQuality.isEmpty) {
            debugPrint('Historical data empty, fetching fresh data...');
            await _fetchHistoricalData();
          } else {
            // Otherwise periodically refresh (every 5 minutes)
            final now = DateTime.now();
            if (now.minute % 5 == 0 && now.second < 10) {
              debugPrint(
                  'Periodic refresh of historical data (5-minute interval)');
              await _fetchHistoricalData();
            }
          }

          // Save to cache
          await _saveToCache();

          // Notify listeners
          _airQualityStreamController.add(_currentAirQuality!);
          _sensorsStreamController.add(_sensorReadings);
        } catch (e) {
          debugPrint('Failed to parse current data: $e');
          throw Exception('Invalid data format from server');
        }
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
      } else {
        // Only show error message if we have a context
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text(
                  'Unable to connect to server. Using cached data if available.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      // Fall back to cached data if available
      if (_currentAirQuality != null) {
        debugPrint('Using cached data due to network error');
        // Notify listeners with cached data
        _airQualityStreamController.add(_currentAirQuality!);
        _sensorsStreamController.add(_sensorReadings);
      }
    }
  }

  // Fetch AI prediction
  Future<void> _fetchAIPrediction() async {
    try {
      final headers = await _getHeaders();

      debugPrint('Fetching AI prediction from: $baseUrl/ai/latest');

      final aiResponse = await http.get(
        Uri.parse('$baseUrl/ai/latest'),
        headers: headers,
      );

      debugPrint('AI prediction response status: ${aiResponse.statusCode}');

      if (aiResponse.statusCode == 200) {
        final aiData = json.decode(aiResponse.body);
        debugPrint('AI prediction: ${aiData['prediction']}');

        // Update the current air quality with AI prediction
        if (_currentAirQuality != null) {
          _currentAirQuality = AirQualityData(
            aqi: _currentAirQuality!.aqi,
            temperature: _currentAirQuality!.temperature,
            humidity: _currentAirQuality!.humidity,
            status: _currentAirQuality!.status,
            timestamp: _currentAirQuality!.timestamp,
            aiPrediction: aiData['prediction'],
          );
        }
      } else {
        debugPrint('Failed to fetch AI prediction: ${aiResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching AI prediction: $e');
    }
  }

  // Fetch historical data
  Future<void> _fetchHistoricalData() async {
    // Prevent multiple concurrent fetches
    if (_fetchingHistoricalData) {
      debugPrint('Historical data fetch already in progress, skipping');
      return;
    }

    _fetchingHistoricalData = true;

    try {
      final headers = await _getHeaders();
      final now = DateTime.now();

      debugPrint('Fetching historical data...');

      // Fetch daily data (24 hours)
      final dailyStart = now.subtract(const Duration(hours: 24));
      final dailyUrl =
          '$baseUrl/sensors/history?start=${dailyStart.toIso8601String()}&end=${now.toIso8601String()}';
      debugPrint('Daily data URL: $dailyUrl');

      final dailyResponse = await http.get(
        Uri.parse(dailyUrl),
        headers: headers,
      );

      debugPrint('Daily data response status: ${dailyResponse.statusCode}');

      if (dailyResponse.statusCode == 200) {
        final List<dynamic> dailyData = json.decode(dailyResponse.body);
        debugPrint('Daily data received: ${dailyData.length} records');

        if (dailyData.isNotEmpty) {
          // Convert the data to AirQualityData objects
          final airQualityDataList =
              dailyData.map((item) => _convertToAirQualityData(item)).toList();

          // Update the list with the new data
          _dailyAirQuality = airQualityDataList;

          // Make sure to add data to the stream
          _dailyAirQualityStreamController.add(_dailyAirQuality);
          debugPrint(
              'Added ${_dailyAirQuality.length} items to daily air quality stream');
        } else {
          debugPrint('No daily data available from API');
        }
      } else {
        debugPrint('Daily data error response: ${dailyResponse.body}');
      }

      // Fetch monthly data (30 days)
      final monthlyStart = now.subtract(const Duration(days: 30));
      final monthlyUrl =
          '$baseUrl/sensors/history?start=${monthlyStart.toIso8601String()}&end=${now.toIso8601String()}';
      debugPrint('Monthly data URL: $monthlyUrl');

      final monthlyResponse = await http.get(
        Uri.parse(monthlyUrl),
        headers: headers,
      );

      debugPrint('Monthly data response status: ${monthlyResponse.statusCode}');

      if (monthlyResponse.statusCode == 200) {
        final List<dynamic> monthlyData = json.decode(monthlyResponse.body);
        debugPrint('Monthly data received: ${monthlyData.length} records');

        if (monthlyData.isNotEmpty) {
          // Convert the data to AirQualityData objects
          final airQualityDataList = monthlyData
              .map((item) => _convertToAirQualityData(item))
              .toList();

          // Update the list with the new data
          _monthlyAirQuality = airQualityDataList;

          // Make sure to add data to the stream
          _monthlyAirQualityStreamController.add(_monthlyAirQuality);
          debugPrint(
              'Added ${_monthlyAirQuality.length} items to monthly air quality stream');
        } else {
          debugPrint('No monthly data available from API');
        }
      } else {
        debugPrint('Monthly data error response: ${monthlyResponse.body}');
      }

      // Save to cache after successful fetch
      await _saveToCache();
    } catch (e) {
      debugPrint('Failed to fetch historical data: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    } finally {
      _fetchingHistoricalData = false;
    }
  }

  // Convert backend data to AirQualityData
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
    } else if (aqi < 150) {
      status = AirQualityStatus.unhealthyForSensitiveGroups;
    } else if (aqi < 200) {
      status = AirQualityStatus.unhealthy;
    } else if (aqi < 300) {
      status = AirQualityStatus.veryUnhealthy;
    } else {
      status = AirQualityStatus.hazardous;
    }

    // Extract the timestamp - ensure it's parsed correctly
    DateTime timestamp;
    try {
      timestamp = DateTime.parse(data['timestamp']);
    } catch (e) {
      debugPrint('Error parsing timestamp: ${data['timestamp']}');
      // Use current time as fallback
      timestamp = DateTime.now();
    }

    return AirQualityData(
      aqi: aqi,
      temperature: data['temperature'] ?? 0.0,
      humidity: data['humidity'] ?? 0.0,
      status: status,
      timestamp: timestamp,
    );
  }

  // Convert backend data to SensorData list
  List<SensorData> _convertToSensorDataList(Map<String, dynamic> data) {
    // Extract the timestamp - ensure it's parsed correctly
    DateTime timestamp;
    try {
      timestamp = DateTime.parse(data['timestamp']);
    } catch (e) {
      debugPrint('Error parsing timestamp: ${data['timestamp']}');
      // Use current time as fallback
      timestamp = DateTime.now();
    }

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

  // Force an immediate data update - include historical refresh flag
  Future<void> refreshData({bool includeHistorical = true}) async {
    await _updateData();

    // Force a refresh of historical data if requested
    if (includeHistorical) {
      debugPrint('Forcing historical data refresh');
      await _fetchHistoricalData();
    }
  }

  // Clean up resources
  void dispose() {
    _updateTimer?.cancel();
    _airQualityStreamController.close();
    _sensorsStreamController.close();
    _dailyAirQualityStreamController.close();
    _monthlyAirQualityStreamController.close();
  }
}
