import 'package:flutter/material.dart';

enum AirQualityStatus {
  good,
  moderate,
  unhealthyForSensitiveGroups,
  unhealthy,
  veryUnhealthy,
  hazardous,
}

class AirQualityData {
  final int aqi;
  final double temperature;
  final double humidity;
  final AirQualityStatus status;
  final DateTime timestamp;
  final String? aiPrediction; // Optional AI prediction

  AirQualityData({
    required this.aqi,
    required this.temperature,
    required this.humidity,
    required this.status,
    required this.timestamp,
    this.aiPrediction,
  });

  // Get color based on air quality status
  Color get statusColor {
    switch (status) {
      case AirQualityStatus.good:
        return Colors.green;
      case AirQualityStatus.moderate:
        return Colors.yellow;
      case AirQualityStatus.unhealthyForSensitiveGroups:
        return Colors.orange;
      case AirQualityStatus.unhealthy:
        return Colors.red;
      case AirQualityStatus.veryUnhealthy:
        return Colors.purple;
      case AirQualityStatus.hazardous:
        return Colors.brown;
    }
  }

  // Get text status
  String get statusText {
    switch (status) {
      case AirQualityStatus.good:
        return 'Good';
      case AirQualityStatus.moderate:
        return 'Moderate';
      case AirQualityStatus.unhealthyForSensitiveGroups:
        return 'Unhealthy for Sensitive Groups';
      case AirQualityStatus.unhealthy:
        return 'Unhealthy';
      case AirQualityStatus.veryUnhealthy:
        return 'Very Unhealthy';
      case AirQualityStatus.hazardous:
        return 'Hazardous';
    }
  }

  // Factory method to create from JSON
  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    return AirQualityData(
      aqi: json['aqi'] as int,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      status: _parseStatus(json['status']),
      timestamp: DateTime.parse(json['timestamp']),
      aiPrediction: json['aiPrediction'],
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
      'aiPrediction': aiPrediction,
    };
  }

  // Helper to parse status from string
  static AirQualityStatus _parseStatus(String? statusStr) {
    if (statusStr == null) return AirQualityStatus.moderate;

    switch (statusStr.toLowerCase()) {
      case 'good':
        return AirQualityStatus.good;
      case 'moderate':
        return AirQualityStatus.moderate;
      case 'unhealthy for sensitive groups':
        return AirQualityStatus.unhealthyForSensitiveGroups;
      case 'unhealthy':
        return AirQualityStatus.unhealthy;
      case 'very unhealthy':
        return AirQualityStatus.veryUnhealthy;
      case 'hazardous':
        return AirQualityStatus.hazardous;
      default:
        return AirQualityStatus.moderate;
    }
  }
}
