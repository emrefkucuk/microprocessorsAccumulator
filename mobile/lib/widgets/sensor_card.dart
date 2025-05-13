import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class SensorCard extends StatelessWidget {
  final SensorData sensorData;

  const SensorCard({
    Key? key,
    required this.sensorData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate appropriate text color based on status color
    final Color statusBgColor = sensorData.statusColor;
    final Color statusTextColor = _getTextColorForBackground(statusBgColor);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sensorData.statusColor.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sensorData.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sensorData.statusColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: statusTextColor, // Use contrasting text color
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getSensorIcon(),
                        size: 32,
                        color: sensorData.statusColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        sensorData.formattedValue,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatTime(sensorData.timestamp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _getSensorDescription(),
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (sensorData.status) {
      case SensorStatus.normal:
        return 'Normal';
      case SensorStatus.warning:
        return 'Warning';
      case SensorStatus.critical:
        return 'Critical';
    }
  }

  IconData _getSensorIcon() {
    switch (sensorData.name) {
      case 'Temperature':
        return Icons.thermostat;
      case 'Humidity':
        return Icons.water_drop;
      case 'CO2':
        return Icons.co2;
      case 'PM2.5':
        return Icons.air;
      case 'PM10':
        return Icons.air; // Using the same icon as PM2.5
      case 'VOC':
        return Icons.science;
      default:
        return Icons.sensors;
    }
  }

  String _getSensorDescription() {
    switch (sensorData.name) {
      case 'Temperature':
        return 'Room temperature measured in degrees Celsius.';
      case 'Humidity':
        return 'Relative humidity percentage in the air.';
      case 'CO2':
        return 'Carbon dioxide concentration in parts per million (ppm).';
      case 'PM2.5':
        return 'Fine particulate matter measuring 2.5 micrometers or less.';
      case 'PM10':
        return 'Coarse particulate matter measuring 10 micrometers or less.';
      case 'VOC':
        return 'Volatile Organic Compounds concentration in the air.';
      default:
        return 'Sensor reading information.';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Determines the best text color (black or white) based on background color
  Color _getTextColorForBackground(Color backgroundColor) {
    // Calculate relative luminance using the formula
    // L = 0.2126 * R + 0.7152 * G + 0.0722 * B
    // where R, G, and B are between 0 and 1

    final double r = backgroundColor.red / 255;
    final double g = backgroundColor.green / 255;
    final double b = backgroundColor.blue / 255;

    final double luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;

    // If luminance is greater than 0.5, use black text; otherwise, use white
    return luminance > 0.6 ? Colors.black : Colors.white;
  }
}
