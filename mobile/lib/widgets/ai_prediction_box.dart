import 'package:flutter/material.dart';
import '../models/air_quality_data.dart';

class AIPredictionBox extends StatelessWidget {
  final AirQualityData airQualityData;

  const AIPredictionBox({
    Key? key,
    required this.airQualityData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no AI prediction is available
    if (airQualityData.aiPrediction == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.only(top: 12.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'AI prediction not available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // Get color and text attributes based on AI prediction
    final Color backgroundColor =
        _getColorForPrediction(airQualityData.aiPrediction!);
    final Color textColor = _getTextColorForBackground(backgroundColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(top: 12.0),
      decoration: BoxDecoration(
        color: backgroundColor,
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
          // Title and status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Prediction',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.smart_toy,
                    color: textColor,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    airQualityData.aiPrediction!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Advice paragraph
          Text(
            _getAdviceForPrediction(airQualityData.aiPrediction!),
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  String _getAdviceForPrediction(String prediction) {
    switch (prediction) {
      case 'GOOD':
        return 'Air quality is satisfactory, and air pollution poses little or no risk. Enjoy outdoor activities!';
      case 'Moderate':
        return 'Air quality is acceptable, but some pollutants may be a concern for very sensitive individuals.';
      case 'Unhealthy for Sensitive Groups':
        return 'Members of sensitive groups may experience health effects. The general public is less likely to be affected.';
      case 'Unhealthy':
        return 'Everyone may begin to experience health effects. Members of sensitive groups may experience more serious effects.';
      case 'Very Unhealthy':
        return 'Health alert: everyone may experience more serious health effects. Avoid outdoor activities.';
      case 'Hazardous':
        return 'Health warning of emergency conditions. The entire population is likely to be affected. Avoid all outdoor exertion.';
      default:
        return '';
    }
  }

  Color _getColorForPrediction(String prediction) {
    switch (prediction) {
      case 'GOOD':
        return Colors.green;
      case 'Moderate':
        return Colors.yellow;
      case 'Unhealthy for Sensitive Groups':
        return Colors.orange;
      case 'Unhealthy':
        return Colors.red;
      case 'Very Unhealthy':
        return Colors.purple;
      case 'Hazardous':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  /// Determines the best text color (black or white) based on background color
  Color _getTextColorForBackground(Color backgroundColor) {
    final double r = backgroundColor.red / 255;
    final double g = backgroundColor.green / 255;
    final double b = backgroundColor.blue / 255;

    final double luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;

    return luminance > 0.6 ? Colors.black : Colors.white;
  }
}
