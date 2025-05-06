import 'package:flutter/material.dart';

enum SensorStatus {
  normal,
  warning,
  critical,
}

class SensorData {
  final String name;
  final double value;
  final String unit;
  final SensorStatus status;
  final DateTime timestamp;

  SensorData({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.timestamp,
  });

  // Get color based on sensor status
  Color get statusColor {
    switch (status) {
      case SensorStatus.normal:
        return Colors.green;
      case SensorStatus.warning:
        return Colors.yellow;
      case SensorStatus.critical:
        return Colors.red;
    }
  }

  // Get formatted value with unit
  String get formattedValue {
    return '$value $unit';
  }

  // Factory method to create from JSON
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      name: json['name'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      status: SensorStatus.values.firstWhere(
        (e) => e.toString() == 'SensorStatus.${json['status']}',
        orElse: () => SensorStatus.normal,
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'unit': unit,
      'status': status.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
