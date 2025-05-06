import 'package:flutter/material.dart';

enum AirQualityStatus {
  good,
  moderate,
  unhealthy,
}

class AirQualityData {
  final int aqi;
  final double temperature;
  final double humidity;
  final AirQualityStatus status;
  final DateTime timestamp;

  AirQualityData({
    required this.aqi,
    required this.temperature,
    required this.humidity,
    required this.status,
    required this.timestamp,
  });

  // Get color based on air quality status
  Color get statusColor {
    switch (status) {
      case AirQualityStatus.good:
        return Colors.green;
      case AirQualityStatus.moderate:
        return Colors.yellow;
      case AirQualityStatus.unhealthy:
        return Colors.red;
    }
  }

  // Get text status
  String get statusText {
    switch (status) {
      case AirQualityStatus.good:
        return 'Good';
      case AirQualityStatus.moderate:
        return 'Moderate';
      case AirQualityStatus.unhealthy:
        return 'Unhealthy';
    }
  }

  // Factory method to create from JSON
  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    return AirQualityData(
      aqi: json['aqi'] as int,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      status: AirQualityStatus.values.firstWhere(
        (e) => e.toString() == 'AirQualityStatus.${json['status']}',
        orElse: () => AirQualityStatus.moderate,
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'aqi': aqi,
      'temperature': temperature,
      'humidity': humidity,
      'status': status.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
