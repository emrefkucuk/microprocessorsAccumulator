import 'package:flutter/material.dart';
import '../models/air_quality_data.dart';

class SummaryBox extends StatelessWidget {
  final AirQualityData airQualityData;

  const SummaryBox({
    Key? key,
    required this.airQualityData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine text color based on background color for better contrast
    final Color textColor =
        _getTextColorForBackground(airQualityData.statusColor);
    final Color subtleTextColor = textColor.withOpacity(0.8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: airQualityData.statusColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with location and AQI in separate rows
          Text(
            'Air Quality: ${airQualityData.statusText}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ankara',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: textColor,
                ),
              ),
              // AQI badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'AQI: ${airQualityData.aqi}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                context,
                icon: Icons.thermostat,
                value: '${airQualityData.temperature.toStringAsFixed(1)}°C',
                label: 'Temperature',
                textColor: textColor,
                subtleTextColor: subtleTextColor,
              ),
              _buildInfoItem(
                context,
                icon: Icons.water_drop,
                value: '${airQualityData.humidity.toStringAsFixed(1)}%',
                label: 'Humidity',
                textColor: textColor,
                subtleTextColor: subtleTextColor,
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Last Updated: ${_formatDateTime(airQualityData.timestamp)}',
            style: TextStyle(
              fontSize: 12,
              color: subtleTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color textColor,
    required Color subtleTextColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: textColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: subtleTextColor,
              ),
            ),
          ],
        ),
      ],
    );
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}, ${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
