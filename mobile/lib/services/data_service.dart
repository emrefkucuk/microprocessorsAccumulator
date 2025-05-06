// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/air_quality_data.dart';
import '../models/sensor_data.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // For real implementation, you would inject these from a DI container
  final String _apiBaseUrl = 'https://your-api-endpoint.com/api';

  // Stream controllers to broadcast data updates
  final _airQualityStreamController =
      StreamController<AirQualityData>.broadcast();
  final _sensorsStreamController =
      StreamController<List<SensorData>>.broadcast();

  // Mock data (temporary until API is ready)
  AirQualityData _currentAirQuality = AirQualityData(
    aqi: 45,
    temperature: 22.5,
    humidity: 55.0,
    status: AirQualityStatus.good,
    timestamp: DateTime.now(),
  );

  List<SensorData> _sensorReadings = [
    SensorData(
      name: 'CO2',
      value: 450.0,
      unit: 'ppm',
      status: SensorStatus.normal,
      timestamp: DateTime.now(),
    ),
    SensorData(
      name: 'Temperature',
      value: 22.5,
      unit: '°C',
      status: SensorStatus.normal,
      timestamp: DateTime.now(),
    ),
    SensorData(
      name: 'Humidity',
      value: 55.0,
      unit: '%',
      status: SensorStatus.normal,
      timestamp: DateTime.now(),
    ),
    SensorData(
      name: 'PM2.5',
      value: 12.3,
      unit: 'μg/m³',
      status: SensorStatus.normal,
      timestamp: DateTime.now(),
    ),
    SensorData(
      name: 'PM10',
      value: 25.7,
      unit: 'μg/m³',
      status: SensorStatus.normal,
      timestamp: DateTime.now(),
    ),
    SensorData(
      name: 'VOC',
      value: 0.15,
      unit: 'mg/m³',
      status: SensorStatus.normal,
      timestamp: DateTime.now(),
    ),
  ];

  // Historical data for graphs (mock data)
  final List<AirQualityData> _dailyAirQuality = [];
  final List<AirQualityData> _monthlyAirQuality = [];

  // Streams that components can listen to
  Stream<AirQualityData> get airQualityStream =>
      _airQualityStreamController.stream;
  Stream<List<SensorData>> get sensorsStream => _sensorsStreamController.stream;

  // Access to current data
  AirQualityData get currentAirQuality => _currentAirQuality;
  List<SensorData> get sensorReadings => _sensorReadings;
  List<AirQualityData> get dailyAirQuality => _dailyAirQuality;
  List<AirQualityData> get monthlyAirQuality => _monthlyAirQuality;

  // Background update timer
  Timer? _updateTimer;

  // Initialize the service
  Future<void> init() async {
    _generateMockHistoricalData();

    // Start periodic updates (every 5 minutes)
    _updateTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => _updateData());

    // Do an initial update
    await _updateData();
  }

  // Generate mock historical data for graphs
  void _generateMockHistoricalData() {
    // Generate daily data (24 hours)
    final now = DateTime.now();
    for (int i = 0; i < 24; i++) {
      final timestamp = now.subtract(Duration(hours: 23 - i));
      _dailyAirQuality.add(AirQualityData(
        aqi: 35 + (i % 3 == 0 ? 15 : 0) + (i % 7 == 0 ? -10 : 0),
        temperature: 20.0 + (i / 2),
        humidity: 50.0 + (i % 5 * 2),
        status: i % 7 == 0 ? AirQualityStatus.moderate : AirQualityStatus.good,
        timestamp: timestamp,
      ));
    }

    // Generate monthly data (30 days)
    for (int i = 0; i < 30; i++) {
      final timestamp = now.subtract(Duration(days: 29 - i));
      _monthlyAirQuality.add(AirQualityData(
        aqi: 40 + (i % 5) * 5 + (i % 10 == 0 ? 20 : 0),
        temperature: 18.0 + (i % 10),
        humidity: 45.0 + (i % 7) * 4,
        status: i % 10 == 0
            ? AirQualityStatus.unhealthy
            : i % 7 == 0
                ? AirQualityStatus.moderate
                : AirQualityStatus.good,
        timestamp: timestamp,
      ));
    }
  }

  // Update data from API (mock for now)
  Future<void> _updateData() async {
    try {
      // In the future, this will call the actual API
      // final response = await http.get(Uri.parse('$_apiBaseUrl/air-quality'));
      // if (response.statusCode == 200) {
      //   final data = json.decode(response.body);
      //   _processAirQualityData(data);
      // }

      // For now, just simulate API updates with random variations
      _simulateDataUpdate();

      // Notify listeners
      _airQualityStreamController.add(_currentAirQuality);
      _sensorsStreamController.add(_sensorReadings);
    } catch (e) {
      debugPrint('Failed to update air quality data: $e');
    }
  }

  // Simulate data updates for development
  void _simulateDataUpdate() {
    final now = DateTime.now();

    // Update CO2
    final co2Index = _sensorReadings.indexWhere((s) => s.name == 'CO2');
    if (co2Index >= 0) {
      final newCO2 = 450.0 + (DateTime.now().minute % 10) * 20;
      final co2Status = newCO2 > 800
          ? SensorStatus.warning
          : newCO2 > 1000
              ? SensorStatus.critical
              : SensorStatus.normal;

      _sensorReadings[co2Index] = SensorData(
        name: 'CO2',
        value: newCO2,
        unit: 'ppm',
        status: co2Status,
        timestamp: now,
      );
    }

    // Update temperature
    final tempIndex =
        _sensorReadings.indexWhere((s) => s.name == 'Temperature');
    if (tempIndex >= 0) {
      final newTemp = 21.0 + (DateTime.now().minute % 5);
      _sensorReadings[tempIndex] = SensorData(
        name: 'Temperature',
        value: newTemp,
        unit: '°C',
        status: SensorStatus.normal,
        timestamp: now,
      );
    }

    // Update humidity
    final humidityIndex =
        _sensorReadings.indexWhere((s) => s.name == 'Humidity');
    if (humidityIndex >= 0) {
      final newHumidity = 50.0 + (DateTime.now().minute % 15);
      _sensorReadings[humidityIndex] = SensorData(
        name: 'Humidity',
        value: newHumidity,
        unit: '%',
        status: SensorStatus.normal,
        timestamp: now,
      );
    }

    // Update PM10
    final pm10Index = _sensorReadings.indexWhere((s) => s.name == 'PM10');
    if (pm10Index >= 0) {
      final newPM10 = 20.0 + (DateTime.now().minute % 12) * 1.5;
      final pm10Status = newPM10 > 50
          ? SensorStatus.warning
          : newPM10 > 100
              ? SensorStatus.critical
              : SensorStatus.normal;

      _sensorReadings[pm10Index] = SensorData(
        name: 'PM10',
        value: newPM10,
        unit: 'μg/m³',
        status: pm10Status,
        timestamp: now,
      );
    }

    // Calculate overall AQI based on sensors
    int newAqi = 30 + (DateTime.now().minute % 7) * 5; // Base value

    // If any sensor is in warning or critical, increase AQI
    for (final sensor in _sensorReadings) {
      if (sensor.status == SensorStatus.warning) newAqi += 20;
      if (sensor.status == SensorStatus.critical) newAqi += 50;
    }

    // Determine overall status
    final status = newAqi < 50
        ? AirQualityStatus.good
        : newAqi < 100
            ? AirQualityStatus.moderate
            : AirQualityStatus.unhealthy;

    // Update current air quality
    _currentAirQuality = AirQualityData(
      aqi: newAqi,
      temperature: _sensorReadings[tempIndex].value,
      humidity: _sensorReadings[humidityIndex].value,
      status: status,
      timestamp: now,
    );

    // Add to historical data if needed (once per hour for daily, once per day for monthly)
    final lastDailyEntry =
        _dailyAirQuality.isNotEmpty ? _dailyAirQuality.last.timestamp : null;
    if (lastDailyEntry == null || now.difference(lastDailyEntry).inHours >= 1) {
      _dailyAirQuality.add(_currentAirQuality);
      if (_dailyAirQuality.length > 24) {
        _dailyAirQuality.removeAt(0);
      }
    }

    final lastMonthlyEntry = _monthlyAirQuality.isNotEmpty
        ? _monthlyAirQuality.last.timestamp
        : null;
    if (lastMonthlyEntry == null ||
        now.difference(lastMonthlyEntry).inDays >= 1) {
      _monthlyAirQuality.add(_currentAirQuality);
      if (_monthlyAirQuality.length > 30) {
        _monthlyAirQuality.removeAt(0);
      }
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
