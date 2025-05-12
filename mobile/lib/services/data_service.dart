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
      }      // Notify listeners with cached data
      if (_currentAirQuality != null) {
        _airQualityStreamController.add(_currentAirQuality!);
      }
      _sensorsStreamController.add(_sensorReadings);
      
      // Notify listeners with cached historical data
      if (_dailyAirQuality.isNotEmpty) {
        _dailyAirQualityStreamController.add(_dailyAirQuality);
      }
      
      if (_monthlyAirQuality.isNotEmpty) {
        _monthlyAirQualityStreamController.add(_monthlyAirQuality);
      }
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

        // Fetch historical data on each update to keep charts current
        await _fetchHistoricalData();

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
        _sensorsStreamController.add(_sensorReadings);      }
    }
  }
  
  // Fetch historical data  
  Future<void> _fetchHistoricalData() async {
    try {
      final headers = await _getHeaders();
      final now = DateTime.now().toUtc().add(const Duration(hours: 3)); // Türkiye saati

      debugPrint('Fetching historical data...');
      
      // Fetch daily data (24 hours)
      final dailyStart = now.subtract(const Duration(hours: 24));
      final dailyUrl = '$baseUrl/sensors/history?start=${dailyStart.toIso8601String()}&end=${now.toIso8601String()}';
      debugPrint('Daily data URL: $dailyUrl');
      
      final dailyResponse = await http.get(
        Uri.parse(dailyUrl),
        headers: headers,
      );

      debugPrint('Daily data response status: ${dailyResponse.statusCode}');
      
      if (dailyResponse.statusCode == 200) {
        final List<dynamic> dailyData = json.decode(dailyResponse.body);
        debugPrint('Daily data received: ${dailyData.length} records');
        
        if (dailyData.isNotEmpty) {          // Process hourly averages for daily chart if we have data
          _dailyAirQuality = _processHourlyAverages(dailyData);
          debugPrint('Daily data processed: ${_dailyAirQuality.length} hourly records');
          
          // Notify listeners with updated daily data
          _dailyAirQualityStreamController.add(_dailyAirQuality);
        } else {
          debugPrint('No daily data available from API');
          // Leave _dailyAirQuality empty to show the "no data" message
          _dailyAirQualityStreamController.add([]);
        }
      } else {
        debugPrint('Daily data error: ${dailyResponse.body}');
        _dailyAirQualityStreamController.add([]);
      }      // Fetch monthly data (30 days)
      final monthlyStart = now.subtract(const Duration(days: 30));
      final monthlyUrl = '$baseUrl/sensors/history?start=${monthlyStart.toIso8601String()}&end=${now.toIso8601String()}';
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
          // Process daily averages for monthly chart if we have data
          _monthlyAirQuality = _processDailyAverages(monthlyData);
          debugPrint('Monthly data processed: ${_monthlyAirQuality.length} daily records');
          
          // Notify listeners with updated monthly data
          _monthlyAirQualityStreamController.add(_monthlyAirQuality);
        } else {
          debugPrint('No monthly data available from API');
          // Leave _monthlyAirQuality empty to show the "no data" message
          _monthlyAirQualityStreamController.add([]);
        }
      } else {
        debugPrint('Monthly data error: ${monthlyResponse.body}');
        _monthlyAirQualityStreamController.add([]);
      }
      
      // Save processed data to cache
      await _saveToCache();
      
    } catch (e) {
      debugPrint('Failed to fetch historical data: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }
  
  // Process data into hourly averages for daily chart
  List<AirQualityData> _processHourlyAverages(List<dynamic> rawData) {
    // Group data by hour
    Map<String, Map<String, dynamic>> hourlyGroups = {};
    
    for (final item in rawData) {
      final timestamp = DateTime.parse(item['timestamp']);
      final hourKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:00';
      
      if (!hourlyGroups.containsKey(hourKey)) {
        hourlyGroups[hourKey] = {
          'temperature': 0.0,
          'humidity': 0.0,
          'pm25': 0.0,
          'pm10': 0.0,
          'co2': 0.0,
          'voc': 0.0,
          'count': 0,
          'timestamp': timestamp.copyWith(minute: 0, second: 0, microsecond: 0),
        };
      }
      
      hourlyGroups[hourKey]!['temperature'] += item['temperature'] ?? 0.0;
      hourlyGroups[hourKey]!['humidity'] += item['humidity'] ?? 0.0;
      hourlyGroups[hourKey]!['pm25'] += item['pm25'] ?? 0.0;
      hourlyGroups[hourKey]!['pm10'] += item['pm10'] ?? 0.0;
      hourlyGroups[hourKey]!['co2'] += item['co2'] ?? 0.0;
      hourlyGroups[hourKey]!['voc'] += item['voc'] ?? 0.0;
      hourlyGroups[hourKey]!['count'] += 1;
    }
    
    // Calculate averages
    List<AirQualityData> hourlyAverages = [];
    hourlyGroups.forEach((hourKey, data) {
      if (data['count'] > 0) {
        final count = data['count'] as int;
        final avgTemp = data['temperature'] / count;
        final avgHumidity = data['humidity'] / count;
        final avgPm25 = data['pm25'] / count;
        final avgPm10 = data['pm10'] / count;
        final avgCo2 = data['co2'] / count;
        
        final aqi = _calculateAQI(avgPm25, avgPm10, avgCo2);
        AirQualityStatus status;
        if (aqi < 50) {
          status = AirQualityStatus.good;
        } else if (aqi < 100) {
          status = AirQualityStatus.moderate;
        } else {
          status = AirQualityStatus.unhealthy;
        }
        
        hourlyAverages.add(AirQualityData(
          aqi: aqi,
          temperature: avgTemp,
          humidity: avgHumidity,
          status: status,
          timestamp: data['timestamp'] as DateTime,
        ));
      }
    });
    
    // Sort by timestamp ascending
    hourlyAverages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return hourlyAverages;
  }
  
  // Process data into daily averages for monthly chart
  List<AirQualityData> _processDailyAverages(List<dynamic> rawData) {
    // Group data by day
    Map<String, Map<String, dynamic>> dailyGroups = {};
    
    for (final item in rawData) {
      final timestamp = DateTime.parse(item['timestamp']);
      final dayKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
      
      if (!dailyGroups.containsKey(dayKey)) {
        dailyGroups[dayKey] = {
          'temperature': 0.0,
          'humidity': 0.0,
          'pm25': 0.0,
          'pm10': 0.0,
          'co2': 0.0,
          'voc': 0.0,
          'count': 0,
          'timestamp': DateTime(timestamp.year, timestamp.month, timestamp.day),
        };
      }
      
      dailyGroups[dayKey]!['temperature'] += item['temperature'] ?? 0.0;
      dailyGroups[dayKey]!['humidity'] += item['humidity'] ?? 0.0;
      dailyGroups[dayKey]!['pm25'] += item['pm25'] ?? 0.0;
      dailyGroups[dayKey]!['pm10'] += item['pm10'] ?? 0.0;
      dailyGroups[dayKey]!['co2'] += item['co2'] ?? 0.0;
      dailyGroups[dayKey]!['voc'] += item['voc'] ?? 0.0;
      dailyGroups[dayKey]!['count'] += 1;
    }
    
    // Calculate averages
    List<AirQualityData> dailyAverages = [];
    dailyGroups.forEach((dayKey, data) {
      if (data['count'] > 0) {
        final count = data['count'] as int;
        final avgTemp = data['temperature'] / count;
        final avgHumidity = data['humidity'] / count;
        final avgPm25 = data['pm25'] / count;
        final avgPm10 = data['pm10'] / count;
        final avgCo2 = data['co2'] / count;
        
        final aqi = _calculateAQI(avgPm25, avgPm10, avgCo2);
        AirQualityStatus status;
        if (aqi < 50) {
          status = AirQualityStatus.good;
        } else if (aqi < 100) {
          status = AirQualityStatus.moderate;
        } else {
          status = AirQualityStatus.unhealthy;
        }
        
        dailyAverages.add(AirQualityData(
          aqi: aqi,
          temperature: avgTemp,
          humidity: avgHumidity,
          status: status,
          timestamp: data['timestamp'] as DateTime,
        ));
      }
    });
    
    // Sort by timestamp ascending
    dailyAverages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return dailyAverages;
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
    await _updateData();
    // Historical data is already fetched in _updateData
  }  // Clean up resources
  void dispose() {
    _updateTimer?.cancel();
    _airQualityStreamController.close();
    _sensorsStreamController.close();
    _dailyAirQualityStreamController.close();
    _monthlyAirQualityStreamController.close();
    _sensorReadings.clear();
    _dailyAirQuality.clear();
    _monthlyAirQuality.clear();
  }
}
